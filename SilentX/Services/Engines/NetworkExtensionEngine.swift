//
//  NetworkExtensionEngine.swift
//  SilentX
//
//  Network Extension-based proxy engine using system VPN tunnel
//  Provides passwordless operation via PacketTunnelProvider
//

#if os(macOS)
import Foundation
import Combine
import NetworkExtension
import OSLog

/// Network Extension-based proxy engine
/// T047-T052: Implements ProxyEngine using ExtensionProfile
@MainActor
final class NetworkExtensionEngine: ProxyEngine {
    
    // MARK: - Private Properties (Logging)
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "NetworkExtensionEngine")
    
    // MARK: - ProxyEngine Protocol
    
    private let statusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    
    var status: ConnectionStatus {
        statusSubject.value
    }
    
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    let engineType: EngineType = .networkExtension
    
    // MARK: - Private Properties
    
    private var extensionProfile: ExtensionProfile?
    private var profileStatusCancellable: AnyCancellable?
    private var configFileURL: URL?
    private let configurationService: any ConfigurationServiceProtocol
    
    // MARK: - Initialization
    
    init(configurationService: (any ConfigurationServiceProtocol)? = nil) {
        self.configurationService = configurationService ?? ConfigurationService()
    }
    
    // MARK: - ProxyEngine Implementation
    
    func start(config: ProxyConfiguration) async throws {
        guard status == .disconnected else {
            throw ProxyError.unknown("Cannot start - already \(status)")
        }
        
        logger.info("Starting NetworkExtensionEngine with config: \(config.configPath.lastPathComponent)")
        statusSubject.send(.connecting)
        
        do {
            // 1. Validate configuration
            try config.validate()
            logger.debug("Configuration validated successfully")
            
            // 2. Verify system extension is installed
            guard await SystemExtension.isInstalled() else {
                logger.error("System extension not installed")
                throw ProxyError.extensionNotInstalled
            }
            logger.debug("System extension is installed")
            
            // 3. Load or install VPN profile
            var profile = try await ExtensionProfile.load()
            if profile == nil {
                logger.info("No VPN profile found, creating new one")
                try await ExtensionProfile.install()
                profile = try await ExtensionProfile.load()
            }
            
            guard let profile = profile else {
                logger.error("Failed to load VPN profile after installation")
                throw ProxyError.extensionLoadFailed("Could not load VPN profile")
            }
            
            extensionProfile = profile
            
            // 4. Subscribe to profile status changes (T052)
            profileStatusCancellable = profile.statusPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newStatus in
                    self?.handleProfileStatusChange(newStatus)
                }
            
            // 5. Copy config to App Group shared container
            try await copyConfigToSharedContainer(config: config)
            
            // 6. Start the VPN tunnel with config path
            let options: [String: NSObject] = [
                "ConfigPath": (FilePath.sharedConfigPath?.path ?? "") as NSObject
            ]
            try await profile.start(options: options)
            
            // 7. Wait for connected status
            try await waitForConnection(timeout: 30.0)
            
            logger.info("Successfully started NetworkExtension proxy")
            
        } catch let error as ProxyError {
            logger.error("Failed to start: \(error.localizedDescription)")
            statusSubject.send(.error(error))
            cleanup()
            throw error
        } catch {
            logger.error("Failed to start: \(error.localizedDescription)")
            let proxyError = ProxyError.unknown(error.localizedDescription)
            statusSubject.send(.error(proxyError))
            cleanup()
            throw proxyError
        }
    }
    
    func stop() async throws {
        switch status {
        case .connected, .connecting:
            break
        default:
            throw ProxyError.unknown("Cannot stop - not connected")
        }
        
        logger.info("Stopping NetworkExtensionEngine...")
        statusSubject.send(.disconnecting)
        
        do {
            if let profile = extensionProfile {
                try await profile.stop()
            }
            
            // Wait briefly for status change
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            cleanup()
            statusSubject.send(.disconnected)
            logger.info("Stopped successfully")
            
        } catch {
            let proxyError = ProxyError.tunnelStartFailed("Failed to stop: \(error.localizedDescription)")
            statusSubject.send(.error(proxyError))
            cleanup()
            throw proxyError
        }
    }
    
    func validate(config: ProxyConfiguration) async -> [ProxyError] {
        var errors: [ProxyError] = []
        
        // Check system extension installation
        if !(await SystemExtension.isInstalled()) {
            errors.append(.extensionNotInstalled)
        }
        
        // Check config file exists
        if !FileManager.default.fileExists(atPath: config.configPath.path) {
            errors.append(.configNotFound)
        }
        
        // Validate config JSON format
        if FileManager.default.fileExists(atPath: config.configPath.path) {
            do {
                let configContent = try String(contentsOf: config.configPath, encoding: .utf8)
                let validation = configurationService.validate(json: configContent)
                if !validation.isValid {
                    errors.append(.configInvalid(validation.errors.first?.message ?? "Invalid JSON"))
                }
            } catch {
                errors.append(.configInvalid("Cannot read configuration file"))
            }
        }
        
        // Check shared container is accessible
        if FilePath.sharedDirectory == nil {
            errors.append(.extensionLoadFailed("App Group container not accessible"))
        }
        
        return errors
    }
    
    // MARK: - Private Methods
    
    /// Handle status changes from ExtensionProfile
    private func handleProfileStatusChange(_ newStatus: ConnectionStatus) {
        // Only update if different and relevant
        switch (status, newStatus) {
        case (.connecting, .connected):
            statusSubject.send(newStatus)
        case (.connected, .disconnecting):
            statusSubject.send(newStatus)
        case (.disconnecting, .disconnected):
            statusSubject.send(newStatus)
        case (.connected, .disconnected):
            // Unexpected disconnection
            statusSubject.send(.error(.tunnelStartFailed("Tunnel disconnected unexpectedly")))
            cleanup()
        case (_, .error):
            statusSubject.send(newStatus)
            cleanup()
        default:
            // Ignore other transitions
            break
        }
    }
    
    /// Copy configuration to App Group shared container
    private func copyConfigToSharedContainer(config: ProxyConfiguration) async throws {
        guard let sharedConfigPath = FilePath.sharedConfigPath else {
            throw ProxyError.extensionLoadFailed("Cannot access App Group container")
        }
        
        // Ensure shared directory exists
        if let sharedDir = FilePath.sharedDirectory {
            try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        }
        
        // Copy config file
        let configContent = try String(contentsOf: config.configPath, encoding: .utf8)
        try configContent.write(to: sharedConfigPath, atomically: true, encoding: .utf8)
        configFileURL = sharedConfigPath
        
        logger.debug("Config copied to shared container: \(sharedConfigPath.path)")
    }
    
    /// Wait for VPN tunnel to connect
    private func waitForConnection(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if case .connected = status {
                return
            }
            if case .error(let error) = status {
                throw error
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        throw ProxyError.timeout
    }
    
    private func cleanup() {
        profileStatusCancellable?.cancel()
        profileStatusCancellable = nil
        extensionProfile = nil
        configFileURL = nil
    }
}

// MARK: - Extension Installation Helper

extension NetworkExtensionEngine {
    
    /// Check if system extension is installed
    static func isExtensionInstalled() async -> Bool {
        await SystemExtension.isInstalled()
    }
    
    /// Install system extension (requires user approval)
    static func installExtension() async throws {
        _ = try await SystemExtension.install()
    }
    
    /// Uninstall system extension
    static func uninstallExtension() async throws {
        _ = try await SystemExtension.uninstall()
    }
}
#endif

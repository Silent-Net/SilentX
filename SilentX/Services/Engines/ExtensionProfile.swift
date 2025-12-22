//
//  ExtensionProfile.swift
//  SilentX
//
//  Manages NETunnelProviderManager for VPN tunnel lifecycle
//  Adapted from sing-box-for-apple reference implementation
//

#if os(macOS)
import Foundation
import Combine
import NetworkExtension
import OSLog

/// VPN tunnel lifecycle manager wrapping NETunnelProviderManager
/// T043-T046: Implements load, install, start, stop, register
@MainActor
final class ExtensionProfile: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var status: ConnectionStatus = .disconnected
    
    // MARK: - Properties
    
    let manager: NETunnelProviderManager
    
    /// Publisher for status changes
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> {
        $status.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "ExtensionProfile")
    private var statusObserver: NSObjectProtocol?
    
    /// Bundle identifier for tunnel extension
    private static var extensionBundleIdentifier: String {
        "\(FilePath.packageName).System"
    }
    
    /// App Group identifier for shared data
    private static var appGroup: String {
        FilePath.groupIdentifier
    }
    
    // MARK: - Initialization
    
    init(_ manager: NETunnelProviderManager) {
        self.manager = manager
        updateStatus(from: manager.connection.status)
        startObservingStatus()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Static Methods
    
    /// Load existing VPN configuration if present
    static func load() async throws -> ExtensionProfile? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        
        for manager in managers {
            guard let tunnelProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                continue
            }
            guard tunnelProtocol.providerBundleIdentifier == extensionBundleIdentifier else {
                continue
            }
            return await ExtensionProfile(manager)
        }
        
        return nil
    }
    
    /// Install a new VPN configuration
    /// Creates and saves a new NETunnelProviderManager
    static func install() async throws {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "SilentX VPN"
        
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = extensionBundleIdentifier
        tunnelProtocol.serverAddress = "SilentX"
        
        // Use App Group for shared storage
        tunnelProtocol.providerConfiguration = [
            "AppGroup": appGroup
        ]
        
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true
        
        try await manager.saveToPreferences()
        
        // Reload to confirm save
        try await manager.loadFromPreferences()
    }
    
    // MARK: - Instance Methods
    
    /// Register profile by saving to preferences
    func register() async throws {
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
    }
    
    /// Start the VPN tunnel
    func start() async throws {
        // Verify extension is installed first
        guard await SystemExtension.isInstalled() else {
            throw ProxyError.extensionNotInstalled
        }
        
        // Reload preferences before starting
        try await manager.loadFromPreferences()
        
        if !manager.isEnabled {
            manager.isEnabled = true
            try await manager.saveToPreferences()
        }
        
        do {
            try manager.connection.startVPNTunnel()
            logger.info("VPN tunnel start requested")
        } catch let error as NEVPNError {
            logger.error("Failed to start VPN tunnel: \(error.localizedDescription)")
            throw ProxyError.tunnelStartFailed(error.localizedDescription)
        } catch {
            logger.error("Failed to start VPN tunnel: \(error.localizedDescription)")
            throw ProxyError.tunnelStartFailed(error.localizedDescription)
        }
    }
    
    /// Start the VPN tunnel with options
    func start(options: [String: NSObject]?) async throws {
        // Verify extension is installed first
        guard await SystemExtension.isInstalled() else {
            throw ProxyError.extensionNotInstalled
        }
        
        // Reload preferences before starting
        try await manager.loadFromPreferences()
        
        if !manager.isEnabled {
            manager.isEnabled = true
            try await manager.saveToPreferences()
        }
        
        do {
            try manager.connection.startVPNTunnel(options: options)
            logger.info("VPN tunnel start requested with options")
        } catch let error as NEVPNError {
            logger.error("Failed to start VPN tunnel: \(error.localizedDescription)")
            throw ProxyError.tunnelStartFailed(error.localizedDescription)
        } catch {
            logger.error("Failed to start VPN tunnel: \(error.localizedDescription)")
            throw ProxyError.tunnelStartFailed(error.localizedDescription)
        }
    }
    
    /// Stop the VPN tunnel
    func stop() async throws {
        manager.connection.stopVPNTunnel()
        logger.info("VPN tunnel stop requested")
    }
    
    /// Remove VPN configuration
    func remove() async throws {
        try await manager.removeFromPreferences()
        logger.info("VPN profile removed")
    }
    
    // MARK: - Private Methods
    
    private func startObservingStatus() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateStatus(from: self.manager.connection.status)
            }
        }
    }
    
    private func updateStatus(from vpnStatus: NEVPNStatus) {
        let newStatus = mapVPNStatus(vpnStatus)
        if status != newStatus {
            logger.debug("Status changed: \(String(describing: vpnStatus)) -> \(String(describing: newStatus))")
            status = newStatus
        }
    }
    
    /// Map NEVPNStatus to ConnectionStatus
    /// T051: NEVPNStatus → ConnectionStatus mapping
    private func mapVPNStatus(_ vpnStatus: NEVPNStatus) -> ConnectionStatus {
        switch vpnStatus {
        case .invalid:
            return .disconnected
        case .disconnected:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            // Create connection info for connected state
            let info = ConnectionInfo(
                engineType: .networkExtension,
                startTime: Date(),
                configName: manager.localizedDescription ?? "SilentX VPN",
                listenPorts: []  // TUN mode doesn't use fixed ports
            )
            return .connected(info)
        case .reasserting:
            return .connecting
        case .disconnecting:
            return .disconnecting
        @unknown default:
            return .disconnected
        }
    }
}

// MARK: - NEVPNStatus Extension

extension NEVPNStatus: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
}
#endif

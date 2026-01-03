//
//  PrivilegedHelperEngine.swift
//  SilentX
//
//  Proxy engine that uses the privileged helper service for passwordless operation
//

import Combine
import Foundation
import os.log

/// Proxy engine that communicates with the privileged helper service
/// for passwordless sing-box management
@MainActor
final class PrivilegedHelperEngine: ProxyEngine {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "PrivilegedHelperEngine")
    
    private let statusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let ipcClient: IPCClient
    private var pollingTask: Task<Void, Never>?
    private var currentConfigName: String?
    private var connectedStartTime: Date?
    private var cachedPorts: [Int] = []
    
    // MARK: - ProxyEngine Protocol
    
    var status: ConnectionStatus {
        statusSubject.value
    }
    
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    let engineType: EngineType = .privilegedHelper
    
    // MARK: - Initialization
    
    init(ipcClient: IPCClient = IPCClient()) {
        self.ipcClient = ipcClient
    }
    
    deinit {
        pollingTask?.cancel()
    }
    
    // MARK: - T073: Initial State Sync
    
    /// Sync initial state on app launch (check if sing-box already running)
    /// Call this when the engine is first created to recover state
    func syncInitialState() async {
        guard status == .disconnected else { return }
        
        do {
            let serviceStatus = try await ipcClient.status()
            
            if serviceStatus.isRunning {
                logger.info("T073: Syncing initial state - service reports core already running")
                connectedStartTime = serviceStatus.startTime ?? Date()
                currentConfigName = serviceStatus.configPath?.components(separatedBy: "/").last
                
                let info = ConnectionInfo(
                    engineType: engineType,
                    startTime: connectedStartTime!,
                    configName: currentConfigName ?? "config.json",
                    listenPorts: []
                )
                statusSubject.send(.connected(info))
                startPolling()
            }
        } catch {
            // Service not available or other error - stay disconnected
            logger.debug("T073: Initial sync failed (service may not be running): \(error.localizedDescription)")
        }
    }
    
    // MARK: - ProxyEngine Implementation
    
    func start(config: ProxyConfiguration) async throws {
        guard status == .disconnected || status.isError else {
            throw ProxyError.unknown("Cannot start - already \(status.displayText)")
        }
        
        
        statusSubject.send(.connecting)
        
        do {
            // Validate configuration
            try config.validate()
            
            // Extract ports for connection info
            cachedPorts = extractPorts(from: config.configPath)
            
            // Store config name for connection info
            currentConfigName = config.configPath.lastPathComponent

            // T117: Check if config is tun-only with auto_route=false but lacks proxy hint
            let (hasTun, autoRoute, systemProxy) = analyzeConfig(from: config.configPath)
            if hasTun && autoRoute == false && systemProxy == nil {
                // Tun-only config without auto_route or http_proxy hint - warn user
                logger.warning("T117: Config is tun-only with auto_route=false but no platform.http_proxy hint")
                // Don't block, but log prominently - traffic may not flow
            }
            
            // Send start command to service
            let pid = try await ipcClient.start(
                configPath: config.configPath.path,
                corePath: config.corePath.path,
                systemProxy: systemProxy
            )
            
            // Trust service response - no delay needed
            // If start command succeeded, core is running
            
            // Update to connected status immediately
            connectedStartTime = Date()
            let info = ConnectionInfo(
                engineType: engineType,
                startTime: connectedStartTime!,
                configName: currentConfigName ?? "config.json",
                listenPorts: cachedPorts
            )
            statusSubject.send(.connected(info))
            
            // Start status polling (will verify in background)
            startPolling()
            
        } catch let error as IPCClientError {
            // T073: Core already running is not an error - sync state instead
            if case .serverError(let code, _) = error,
               code == IPCErrorCode.coreAlreadyRunning.rawValue {
                logger.info("Core is already running - syncing state")
                
                // Get current status and sync
                do {
                    let serviceStatus = try await ipcClient.status()
                    if serviceStatus.isRunning {
                        connectedStartTime = serviceStatus.startTime ?? Date()
                        let info = ConnectionInfo(
                            engineType: engineType,
                            startTime: connectedStartTime!,
                            configName: currentConfigName ?? "config.json",
                            listenPorts: cachedPorts
                        )
                        statusSubject.send(.connected(info))
                        startPolling()
                        logger.info("Synced state - core was already running")
                        return // Success - core was already running
                    }
                } catch {
                    logger.warning("Failed to sync state after core already running: \(error.localizedDescription)")
                }
            }
            
            logger.error("IPC error during start: \(error.localizedDescription)")
            let proxyError = mapIPCError(error)
            statusSubject.send(.error(proxyError))
            throw proxyError
            
        } catch let error as ProxyError {
            logger.error("Proxy error during start: \(error.localizedDescription)")
            statusSubject.send(.error(error))
            throw error
            
        } catch {
            logger.error("Unexpected error during start: \(error.localizedDescription)")
            let proxyError = ProxyError.unknown(error.localizedDescription)
            statusSubject.send(.error(proxyError))
            throw proxyError
        }
    }
    
    func stop() async throws {
        // Allow stopping from connected or error states
        switch status {
        case .connected, .error:
            break // Proceed with stop
        case .disconnected:
            return // Already stopped
        case .connecting, .disconnecting:
            throw ProxyError.unknown("Cannot stop - operation in progress")
        }
        
        logger.info("Stopping PrivilegedHelperEngine...")
        statusSubject.send(.disconnecting)
        
        // Stop polling first
        pollingTask?.cancel()
        pollingTask = nil
        
        do {
            // Send stop command to service
            try await ipcClient.stop()
            logger.info("Service stopped sing-box successfully")
            
        } catch let error as IPCClientError {
            // If service is unavailable, consider it stopped
            if error.isServiceUnavailable {
                logger.warning("Service unavailable during stop - assuming already stopped")
            } else {
                logger.error("IPC error during stop: \(error.localizedDescription)")
                // Still transition to disconnected on stop failure
            }
            
        } catch {
            logger.error("Error during stop: \(error.localizedDescription)")
            // Still transition to disconnected on stop failure
        }
        
        // Clear state
        currentConfigName = nil
        connectedStartTime = nil
        cachedPorts = []
        
        statusSubject.send(.disconnected)
        logger.info("Stopped successfully")
    }
    
    func validate(config: ProxyConfiguration) async -> [ProxyError] {
        var errors: [ProxyError] = []
        
        // Check config file exists
        if !FileManager.default.fileExists(atPath: config.configPath.path) {
            errors.append(.configNotFound)
        }
        
        // Check core binary exists
        if !FileManager.default.fileExists(atPath: config.corePath.path) {
            errors.append(.coreNotFound)
        }
        
        // Check service is available
        let serviceAvailable = await IPCClient.isServiceAvailable()
        if !serviceAvailable {
            errors.append(.unknown("Privileged helper service is not available. Please install it in Settings."))
        }
        
        return errors
    }
    
    // MARK: - Service Availability Check
    
    /// Check if the privileged helper service is installed and running
    static func isServiceAvailable() async -> Bool {
        return await IPCClient.isServiceAvailable()
    }
    
    /// Check if the service is installed (plist exists)
    static func isServiceInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: ServicePaths.plistPath)
    }
    
    // MARK: - Status Polling
    
    /// Start polling with configurable interval
    /// T069: Use faster polling (500ms) during connecting/disconnecting states
    private func startPolling(fastMode: Bool = false) {
        pollingTask?.cancel()
        
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                
                // T069: Fast polling (500ms) during transitions, normal (2s) otherwise
                let interval: UInt64 = fastMode ? 500_000_000 : 2_000_000_000
                try? await Task.sleep(nanoseconds: interval)
                
                guard !Task.isCancelled else { return }
                
                await self.pollStatus()
            }
        }
    }
    
    private func pollStatus() async {
        do {
            let serviceStatus = try await ipcClient.status()
            
            await MainActor.run {
                switch status {
                case .connected:
                    if !serviceStatus.isRunning {
                        // Process died - check if it crashed
                        logger.warning("Service reports core is no longer running")
                        pollingTask?.cancel()
                        pollingTask = nil
                        
                        // T068: Include crash reason if available
                        if let exitCode = serviceStatus.lastExitCode, exitCode != 0 {
                            let reason = serviceStatus.errorReason ?? "Exit code: \(exitCode)"
                            statusSubject.send(.error(.coreStartFailed("Core crashed: \(reason)")))
                        } else {
                            statusSubject.send(.error(.coreStartFailed("Core process terminated unexpectedly")))
                        }
                    } else {
                        // Update connection info with latest uptime
                        let info = ConnectionInfo(
                            engineType: engineType,
                            startTime: connectedStartTime ?? Date(),
                            configName: currentConfigName ?? "config.json",
                            listenPorts: cachedPorts
                        )
                        statusSubject.send(.connected(info))
                    }
                    
                case .disconnected:
                    // T073: If we're disconnected but service shows running, sync state
                    if serviceStatus.isRunning {
                        logger.info("Syncing state: service reports core is running")
                        connectedStartTime = serviceStatus.startTime ?? Date()
                        let info = ConnectionInfo(
                            engineType: engineType,
                            startTime: connectedStartTime!,
                            configName: serviceStatus.configPath?.components(separatedBy: "/").last ?? "config.json",
                            listenPorts: []
                        )
                        statusSubject.send(.connected(info))
                        startPolling()
                    }
                    
                default:
                    break
                }
            }
            
        } catch let error as IPCClientError {
            // Service communication failed
            if error.isServiceUnavailable {
                await MainActor.run {
                    if case .connected = status {
                        logger.error("Lost connection to service")
                        pollingTask?.cancel()
                        pollingTask = nil
                        statusSubject.send(.error(.unknown("Lost connection to privileged helper service")))
                    }
                }
            }
        } catch {
            logger.error("Poll error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func extractPorts(from configPath: URL) -> [Int] {
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return []
        }
        
        var ports: [Int] = []
        for inbound in inbounds {
            if let port = inbound["listen_port"] as? Int {
                ports.append(port)
            }
        }
        return ports
    }

    /// Analyze config for TUN settings and system proxy requirements
    /// Returns: (hasTunInbound, autoRoute value if present, SystemProxySettings if applicable)
    private func analyzeConfig(from configPath: URL) -> (hasTun: Bool, autoRoute: Bool?, systemProxy: SystemProxySettings?) {
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return (false, nil, nil)
        }

        var hasTun = false
        var autoRoute: Bool? = nil
        var systemProxy: SystemProxySettings? = nil

        for inbound in inbounds {
            guard (inbound["type"] as? String) == "tun" else { continue }
            hasTun = true
            
            // Check auto_route setting
            if let ar = inbound["auto_route"] as? Bool {
                autoRoute = ar
            }
            
            // Check for platform.http_proxy hint
            if let platform = inbound["platform"] as? [String: Any],
               let httpProxy = platform["http_proxy"] as? [String: Any],
               (httpProxy["enabled"] as? Bool) == true,
               let port = httpProxy["server_port"] as? Int {
                let host = (httpProxy["server"] as? String) ?? "127.0.0.1"
                systemProxy = SystemProxySettings(
                    enabled: true,
                    host: host,
                    port: port,
                    bypassDomains: ["localhost", "127.0.0.1"]
                )
            }
            
            break // Only process first TUN inbound
        }

        return (hasTun, autoRoute, systemProxy)
    }
    
    private func mapIPCError(_ error: IPCClientError) -> ProxyError {
        switch error {
        case .connectionFailed(let reason):
            if reason.contains("not running") || reason.contains("not found") {
                return .unknown("Privileged helper service is not running. Please install it in Settings.")
            }
            return .unknown("Service connection failed: \(reason)")
            
        case .serverError(let code, let message):
            switch code {
            case IPCErrorCode.configNotFound.rawValue:
                return .configNotFound
            case IPCErrorCode.coreNotFound.rawValue:
                return .coreNotFound
            case IPCErrorCode.coreStartFailed.rawValue:
                return .coreStartFailed(message)
            case IPCErrorCode.coreAlreadyRunning.rawValue:
                return .unknown("Core is already running")
            default:
                return .unknown("Service error: \(message)")
            }
            
        case .timeout:
            return .timeout
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - ConnectionStatus Extension

private extension ConnectionStatus {
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

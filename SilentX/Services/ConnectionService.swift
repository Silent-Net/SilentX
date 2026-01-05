//
//  ConnectionService.swift
//  SilentX
//
//  Connection service for managing proxy connections
//

import Foundation
import SwiftUI
import Combine
import SwiftData
import Darwin.POSIX.net
import Darwin.POSIX.ifaddrs
#if os(macOS)
import UserNotifications
#endif

/// Protocol for connection service
protocol ConnectionServiceProtocol: ObservableObject {
    /// Current connection status
    var status: ConnectionStatus { get }

    /// Starts proxy connection with provided profile
    func connect(profile: Profile) async throws

    /// Stops proxy connection
    func disconnect() async throws

    /// Restarts connection (for config changes)
    func restart() async throws
}

/// Connection service that manages proxy lifecycle using ProxyEngine abstraction
@MainActor
final class ConnectionService: ConnectionServiceProtocol, ObservableObject {
    
    // MARK: - Shared Instance
    
    static let shared = ConnectionService()

    // MARK: - Published Properties

    @Published private(set) var status: ConnectionStatus = .disconnected

    // MARK: - Private Properties

    private var lastProfile: Profile?
    private var currentEngine: (any ProxyEngine)?
    private var cancellables = Set<AnyCancellable>()
    private let coreVersionService: any CoreVersionServiceProtocol
    private var activeRuntimeConfigURL: URL?
    private var reconnectTask: Task<Void, Never>?
    
    // MARK: - Settings (Auto-Reconnect)
    
    @AppStorage("autoReconnectOnDisconnect") private var autoReconnectOnDisconnect = true
    @AppStorage("reconnectDelay") private var reconnectDelay = 5.0
    
    // MARK: - Settings (Notifications)
    
    @AppStorage("notifyOnConnect") private var notifyOnConnect = true
    @AppStorage("notifyOnDisconnect") private var notifyOnDisconnect = true
    @AppStorage("notifyOnError") private var notifyOnError = true

    // MARK: - Public Accessors
    
    /// Active config file path (for Groups panel to parse)
    var activeConfigPath: URL? {
        activeRuntimeConfigURL
    }
    
    // MARK: - Proxy Mode & System Proxy
    
    /// Current proxy mode (rule/global/direct)
    @Published var proxyMode: String = "rule"
    
    /// Clash API port from active config (for logs WebSocket)
    @Published private(set) var clashAPIPort: Int? = 9090
    
    /// HTTP proxy port from active config
    var httpPort: Int? {
        // Parse from active config or return default
        guard let configURL = activeRuntimeConfigURL,
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return nil
        }
        
        for inbound in inbounds {
            if let type = inbound["type"] as? String,
               (type == "http" || type == "mixed"),
               let port = inbound["listen_port"] as? Int {
                return port
            }
        }
        return nil
    }
    
    /// SOCKS proxy port from active config
    var socksPort: Int? {
        guard let configURL = activeRuntimeConfigURL,
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return nil
        }
        
        for inbound in inbounds {
            if let type = inbound["type"] as? String,
               (type == "socks" || type == "mixed"),
               let port = inbound["listen_port"] as? Int {
                return port
            }
        }
        return nil
    }
    
    /// Whether system HTTP proxy is enabled (stub - needs networksetup integration)
    var isSystemHttpProxyEnabled: Bool { false }
    
    /// Whether system SOCKS proxy is enabled (stub - needs networksetup integration)
    var isSystemSocksProxyEnabled: Bool { false }
    
    /// Set system proxy settings
    func setSystemProxy(httpEnabled: Bool, socksEnabled: Bool) async throws {
        let service = SystemProxyService()
        
        if httpEnabled || socksEnabled {
            // Enable proxy with the current port from active config
            guard let port = httpPort ?? socksPort else {
                throw ConnectionError.configurationError("No proxy port available")
            }
            try service.enableProxy(host: "127.0.0.1", port: port)
        } else {
            // Disable - restore original settings
            try service.restoreOriginalSettings()
        }
    }
    
    /// Change proxy mode via Clash API
    func setProxyMode(_ mode: String) async throws {
        proxyMode = mode
        // Call Clash API to change mode
        try await ClashAPIClient.shared.setMode(mode)
    }

    // MARK: - Initialization

    init(
        coreVersionService: (any CoreVersionServiceProtocol)? = nil
    ) {
        self.coreVersionService = coreVersionService ?? {
            let context = ModelContext(SilentXApp.sharedModelContainer)
            return CoreVersionService(modelContext: context)
        }()
    }

    // MARK: - Public Methods

    func connect(profile: Profile) async throws {
        // Don't allow connecting if already connected or in transition
        switch status {
        case .connected, .connecting, .disconnecting:
            throw ConnectionError.invalidState
        default:
            break
        }

        lastProfile = profile

        // Create engine based on profile preference with fallback logic
        let engine: any ProxyEngine = try await selectEngine(for: profile)
        currentEngine = engine

        // T021: Subscribe to engine status updates
        engine.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                self?.handleStatusChange(newStatus)
            }
            .store(in: &cancellables)

        // Show progress immediately (preflight can take a moment)
        status = .connecting

        // Prepare configuration
        let profileConfigURL = FilePath.profilePath(for: profile.id)
        let runtimeConfigURL = FilePath.runtimeConfigPath(for: profile.id)

        // Always persist the *raw* profile JSON for inspection/export.
        try profile.configurationJSON.write(to: profileConfigURL, atomically: true, encoding: .utf8)

        // ONLY remove interface_name from TUN inbound - let sing-box auto-select
        // This prevents "resource busy" when hardcoded utun is occupied
        // Everything else stays exactly as-is, just like terminal
        var runtimeConfigJSON = profile.configurationJSON
        runtimeConfigJSON = clearTunInterfaceName(runtimeConfigJSON)
        
        try runtimeConfigJSON.write(to: runtimeConfigURL, atomically: true, encoding: .utf8)
        activeRuntimeConfigURL = runtimeConfigURL
        
        // Parse config for Clash API port
        if let data = runtimeConfigJSON.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Configure ClashAPIClient with port from config
            if let experimental = json["experimental"] as? [String: Any],
               let clashApi = experimental["clash_api"] as? [String: Any],
               let controller = clashApi["external_controller"] as? String {
                // Parse port from "127.0.0.1:9099" format
                let parts = controller.split(separator: ":")
                if parts.count == 2, let port = Int(parts[1]) {
                    clashAPIPort = port
                    await ClashAPIClient.shared.configure(port: port)
                }
            }
        }

        let coreURL = try resolveCoreBinary()

        let config = ProxyConfiguration(
            profileId: profile.id,
            configPath: runtimeConfigURL,
            corePath: coreURL,
            logLevel: .info
        )

        // T020: Delegate to engine.start()
        try await engine.start(config: config)
    }


    func disconnect() async throws {
        guard let engine = currentEngine else {
            throw ConnectionError.noActiveConnection
        }

        // If already disconnecting, block; if already disconnected, no-op; allow cancel during connecting
        if case .disconnecting = status { throw ConnectionError.invalidState }
        if case .disconnected = status { return }

        // Ensure UI reflects transition even if engine status events are delayed
        status = .disconnecting

        // T020: Delegate to engine.stop()
        try await engine.stop()

        // Fallback: ensure UI reaches disconnected even if engine status missed
        if case .disconnected = status {
            // Already updated by engine
        } else {
            status = .disconnected
        }

        // Cleanup
        currentEngine = nil
        cancellables.removeAll()
        activeRuntimeConfigURL = nil
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    func restart() async throws {
        if case .connected = status {
            try await disconnect()
        }
        if let profile = lastProfile {
            try await connect(profile: profile)
        } else {
            throw ConnectionError.noActiveProfile
        }
    }
    
    // MARK: - Status Handling
    
    /// Handle status changes from engine, including auto-reconnect logic
    private func handleStatusChange(_ newStatus: ConnectionStatus) {
        let previousStatus = status
        status = newStatus
        
        // Send notifications based on status changes
        sendNotificationIfNeeded(from: previousStatus, to: newStatus)
        
        // Check for unexpected disconnection (was connected, now disconnected/error)
        switch (previousStatus, newStatus) {
        case (.connected, .disconnected), (.connected, .error):
            // Connection dropped unexpectedly - attempt reconnect if enabled
            if autoReconnectOnDisconnect, let profile = lastProfile {
                scheduleReconnect(profile: profile)
            }
        default:
            break
        }
    }
    
    /// Send system notification based on status change
    private func sendNotificationIfNeeded(from oldStatus: ConnectionStatus, to newStatus: ConnectionStatus) {
        #if os(macOS)
        switch newStatus {
        case .connected(let info):
            if notifyOnConnect && !oldStatus.isConnected {
                sendNotification(
                    title: "Connected",
                    body: "SilentX is now connected via \(info.engineType.displayName)"
                )
            }
        case .disconnected:
            if notifyOnDisconnect && oldStatus.isConnected {
                sendNotification(
                    title: "Disconnected",
                    body: "SilentX proxy connection has been stopped"
                )
            }
        case .error(let error):
            if notifyOnError {
                sendNotification(
                    title: "Connection Error",
                    body: error.localizedDescription
                )
            }
        default:
            break
        }
        #endif
    }
    
    #if os(macOS)
    /// Send a macOS notification using UserNotifications framework
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    #endif
    
    /// Schedule a reconnection attempt after the configured delay
    private func scheduleReconnect(profile: Profile) {
        // Cancel any existing reconnect task
        reconnectTask?.cancel()
        
        let delaySeconds = reconnectDelay
        
        reconnectTask = Task { [weak self] in
            // Wait for the configured delay
            if delaySeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
            
            // Check if task was cancelled or we're already reconnecting
            guard !Task.isCancelled else { return }
            guard let self = self else { return }
            
            // Only attempt reconnect if still disconnected
            guard case .disconnected = self.status else { return }
            
            do {
                try await self.connect(profile: profile)
            } catch {
                // Reconnect failed - could retry again, but for now just log
                print("Auto-reconnect failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    /// Select the appropriate engine based on service availability
    /// Priority: PrivilegedHelper (if running) > Profile preference > LocalProcess (fallback)
    /// 
    /// KEY LOGIC: When Background Service is installed and running, ALWAYS use it
    /// for passwordless operation. This is the whole point of installing the service.
    private func selectEngine(for profile: Profile) async throws -> any ProxyEngine {
        // PRIORITY 1: If Background Service is available, ALWAYS use it (passwordless!)
        // This is the main feature - user installed service to avoid password prompts
        if await PrivilegedHelperEngine.isServiceAvailable() {
            return PrivilegedHelperEngine()
        }
        
        // PRIORITY 2: Check profile preference for other engines
        switch profile.preferredEngine {
        case .privilegedHelper:
            // Service was requested but not available
            if PrivilegedHelperEngine.isServiceInstalled() {
                throw ConnectionError.engineNotAvailable(
                    "Privileged helper service is not responding.\nPlease check Settings → Proxy Mode."
                )
            }
            throw ConnectionError.engineNotAvailable(
                "Privileged helper service not installed.\nPlease install it in Settings → Proxy Mode for passwordless operation."
            )
            
        case .networkExtension:
            #if os(macOS)
            if !(await NetworkExtensionEngine.isExtensionInstalled()) {
                throw ConnectionError.engineNotAvailable(
                    "System Extension not installed.\nPlease install it in Settings → Proxy Mode."
                )
            }
            return NetworkExtensionEngine()
            #else
            throw ConnectionError.engineNotAvailable("NetworkExtension engine not available on this platform")
            #endif
            
        case .localProcess:
            // Fall through to LocalProcessEngine
            break
        }
        
        // PRIORITY 3: Fallback to LocalProcessEngine (requires password each time)
        return LocalProcessEngine()
    }

    private func resolveCoreBinary() throws -> URL {
        // Method 1: Try active version from CoreVersionService
        if let active = coreVersionService.activeVersion?.localPath {
            let url = URL(fileURLWithPath: active)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Method 2: Try first cached version from CoreVersionService
        if let firstCached = coreVersionService.cachedVersions.first?.localPath {
            let url = URL(fileURLWithPath: firstCached)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Method 3: Directly scan FilePath.cores directory
        let coresDir = FilePath.cores
        if let contents = try? FileManager.default.contentsOfDirectory(at: coresDir, includingPropertiesForKeys: nil) {
            for versionDir in contents where versionDir.hasDirectoryPath {
                let binaryURL = versionDir.appendingPathComponent("sing-box")
                if FileManager.default.fileExists(atPath: binaryURL.path) {
                    return binaryURL
                }
            }
        }

        // Method 4: Try default version path
        let defaultPath = FilePath.singBoxBinary(for: Constants.defaultSingBoxVersion)
        if FileManager.default.fileExists(atPath: defaultPath.path) {
            return defaultPath
        }

        // Method 5: Direct database query as last resort
        let descriptor = FetchDescriptor<CoreVersion>(
            predicate: #Predicate<CoreVersion> { $0.localPath != nil }
        )
        if let versions = try? SilentXApp.sharedModelContainer.mainContext.fetch(descriptor) {
            // Prefer active version
            if let active = versions.first(where: { $0.isActive }), let path = active.localPath {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            // Try any version
            for version in versions {
                if let path = version.localPath {
                    let url = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        return url
                    }
                }
            }
        }

        throw ConnectionError.coreError(
            "Sing-Box core not found.\nPlease download a core version in Settings."
        )
    }

    private func preflightSingBoxCheck(coreURL: URL, configURL: URL) async throws {
        // Important: run in config directory so relative paths (rules, geosite, etc.) behave like terminal runs.
        let workingDirectory = configURL.deletingLastPathComponent()
        let args = ["check", "-c", configURL.path]

        let result = try await runProcess(
            executableURL: coreURL,
            arguments: args,
            currentDirectoryURL: workingDirectory
        )

        let combined = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard result.exitCode == 0 else {
            let detail: String
            if combined.isEmpty {
                detail = "sing-box check exited with code \(result.exitCode), no output"
            } else {
                detail = "sing-box check exited with code \(result.exitCode)\n\n\(combined)"
            }
            throw ProxyError.configInvalid(detail)
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectoryURL

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }
        }
    }

    /// Ensure config has a mixed inbound for HTTP/SOCKS proxy
    /// This is needed because some subscription configs only have TUN inbound
    private func ensureMixedInbound(_ configJSON: String) throws -> String {
        guard let data = configJSON.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var inbounds = json["inbounds"] as? [[String: Any]] else {
            return configJSON
        }
        
        // Check if mixed inbound already exists
        let hasMixed = inbounds.contains { ($0["type"] as? String) == "mixed" }
        if hasMixed {
            return configJSON
        }
        
        // Find the port from TUN's platform.http_proxy or use default 2088
        var mixedPort = 2088
        for inbound in inbounds {
            if let platform = inbound["platform"] as? [String: Any],
               let httpProxy = platform["http_proxy"] as? [String: Any],
               let port = httpProxy["server_port"] as? Int {
                mixedPort = port
                break
            }
        }
        
        // Add mixed inbound
        let mixedInbound: [String: Any] = [
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": mixedPort,
            "sniff": true,
            "sniff_override_destination": false,
            "set_system_proxy": false
        ]
        
        inbounds.insert(mixedInbound, at: 0)
        json["inbounds"] = inbounds
        
        guard let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let newJSON = String(data: newData, encoding: .utf8) else {
            return configJSON
        }
        
        return newJSON
    }
    
    /// Check if another VPN/TUN is active (e.g., SFM, Clash, etc.)
    /// If so, we should use HTTP-only mode to avoid conflicts
    private func isOtherTunActive() -> Bool {
        // macOS can have many `utun*` interfaces even when no VPN is active.
        // We only treat “other VPN active” as true when the system default route
        // is currently bound to a tunnel-like interface.
        guard let defaultIface = defaultRouteInterfaceIPv4() else { return false }
        return defaultIface.hasPrefix("utun") || defaultIface.hasPrefix("ppp") || defaultIface.hasPrefix("ipsec")
    }

    private func defaultRouteInterfaceIPv4() -> String? {
        // `route -n get default` is the most stable way to discover the active
        // default route interface on macOS.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for rawLine in output.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("interface:") else { continue }
                return line.replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// Remove TUN inbound from config when other VPN is active
    /// This allows SilentX to coexist with other VPN apps (SFM, Clash, etc.)
    private func removeTunInboundIfNeeded(_ configJSON: String) throws -> String {
        // Only remove TUN if another VPN is active
        guard isOtherTunActive() else {
            return configJSON
        }
        
        guard let data = configJSON.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var inbounds = json["inbounds"] as? [[String: Any]] else {
            return configJSON
        }
        
        // Remove TUN inbounds
        let originalCount = inbounds.count
        inbounds.removeAll { ($0["type"] as? String) == "tun" }
        
        if inbounds.count < originalCount {
            // TUN was removed, make sure we have a mixed inbound
            let hasMixed = inbounds.contains { ($0["type"] as? String) == "mixed" }
            if !hasMixed {
                // Find port from removed TUN's platform.http_proxy or from json backup
                var mixedPort: Int?
                if let originalInbounds = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["inbounds"] as? [[String: Any]] {
                    for inbound in originalInbounds where inbound["type"] as? String == "tun" {
                        if let platform = inbound["platform"] as? [String: Any],
                           let httpProxy = platform["http_proxy"] as? [String: Any],
                           let port = httpProxy["server_port"] as? Int {
                            mixedPort = port
                            break
                        }
                    }
                }
                
                // Add mixed inbound with port from config
                let mixedInbound: [String: Any] = [
                    "type": "mixed",
                    "tag": "mixed-in",
                    "listen": "127.0.0.1",
                    "listen_port": mixedPort ?? 2080,  // fallback only if not found
                    "sniff": true,
                    "sniff_override_destination": false,
                    "set_system_proxy": false
                ]
                inbounds.insert(mixedInbound, at: 0)
            }
            
            json["inbounds"] = inbounds
            
            guard let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
                  let newJSON = String(data: newData, encoding: .utf8) else {
                return configJSON
            }
            
            return newJSON
        }
        
        return configJSON
    }
    
    /// Prepare TUN config: remove interface_name to let sing-box auto-select
    private func clearTunInterfaceName(_ configJSON: String) -> String {
        guard let data = configJSON.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var inbounds = json["inbounds"] as? [[String: Any]] else {
            return configJSON
        }
        
        var modified = false
        for i in 0..<inbounds.count {
            guard (inbounds[i]["type"] as? String) == "tun" else { continue }
            
            // Remove interface_name to let sing-box auto-select
            if inbounds[i]["interface_name"] != nil {
                inbounds[i].removeValue(forKey: "interface_name")
                modified = true
            }
        }
        
        guard modified else { return configJSON }
        
        json["inbounds"] = inbounds
        guard let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let newJSON = String(data: newData, encoding: .utf8) else {
            return configJSON
        }
        return newJSON
    }
}

/// Connection errors
enum ConnectionError: LocalizedError {
    case invalidState
    case noActiveProfile
    case noActiveConnection
    case configurationError(String)
    case coreError(String)
    case engineNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "Cannot toggle connection in current state"
        case .noActiveProfile:
            return "No profile selected"
        case .noActiveConnection:
            return "No active connection"
        case .configurationError(let detail):
            return "Configuration error: \(detail)"
        case .coreError(let detail):
            return "Core error: \(detail)"
        case .engineNotAvailable(let detail):
            return "Engine not available: \(detail)"
        }
    }
}

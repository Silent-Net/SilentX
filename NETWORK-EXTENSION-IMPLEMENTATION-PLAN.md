# Network Extension Implementation Plan for SilentX

**Created**: December 6, 2025
**Based on**: Sing-Box for Apple (SFM) reference implementation analysis
**Status**: Planning Phase

---

## Executive Summary

This document outlines the implementation plan to add **real Sing-Box core integration** to SilentX using the **Network Extension (NEPacketTunnelProvider)** architecture, based on the analysis of the SFM reference implementation.

### Key Insight: Why Mock Connection Works

The current **mock implementation doesn't bind to any ports** - it just simulates connection state changes. That's why it doesn't conflict with SFM running on port 2080.

### Architecture Change Required

To implement real functionality, we need to:
1. **Embed Sing-Box as Libbox.xcframework** (Go Mobile compiled framework)
2. **Create Network Extension target** (NEPacketTunnelProvider)
3. **Traffic flows through TUN interface** (NOT traditional port binding on host)
4. **Listeners exist INSIDE the extension process** (isolated from host network)

**This solves the port conflict issue** - both SFM and SilentX can run simultaneously because they use separate Network Extension processes with isolated network namespaces.

---

## Phase 1: Project Setup & Architecture

### 1.1 Obtain Libbox Framework

**Option A: Use Pre-built Framework from SFM**
- Location: `/Users/xmx/workspace/Silent-Net/RefRepo/sing-box-for-apple/Frameworks/Libbox.xcframework`
- Advantage: Ready to use immediately
- Disadvantage: Version may be outdated

**Option B: Build from Source** (Recommended for production)
- Clone sing-box source: https://github.com/SagerNet/sing-box
- Build using Go Mobile: `make lib_install`
- Generates `Libbox.xcframework` with latest version

**Action Items**:
- [ ] Copy Libbox.xcframework to `SilentX/Frameworks/`
- [ ] Add framework to Xcode project
- [ ] Verify framework architecture (arm64 for Apple Silicon Mac)

### 1.2 Configure App Groups

**Purpose**: Share database and configuration between main app and Network Extension

**Steps**:
1. Create App Group identifier: `group.Silent-Net.SilentX`
2. Enable App Groups capability in:
   - SilentX (main app)
   - SilentXExtension (to be created)
3. Update FilePath constants

**File Changes**:
```swift
// SilentX/Shared/FilePath.swift
public enum FilePath {
    public static let packageName = "Silent-Net.SilentX"
    static let groupName = "group.\(packageName)"

    public static let sharedDirectory: URL! = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: FilePath.groupName
    )

    public static let cacheDirectory: URL {
        sharedDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    }

    public static let workingDirectory: URL {
        cacheDirectory.appendingPathComponent("Working", isDirectory: true)
    }
}
```

### 1.3 Create Network Extension Target

**Steps**:
1. In Xcode: File → New → Target → Network Extension
2. Name: `SilentXExtension`
3. Bundle ID: `Silent-Net.SilentX.extension`
4. Select Provider Type: `Packet Tunnel`

**Project Structure**:
```
SilentX.xcodeproj/
├── SilentX/                    # Main app
├── SilentXExtension/           # Network Extension (NEW)
│   ├── PacketTunnelProvider.swift
│   ├── Info.plist
│   └── SilentXExtension.entitlements
├── SilentXTests/
├── SilentXUITests/
└── Frameworks/
    └── Libbox.xcframework      # Add this
```

---

## Phase 2: Shared Library Foundation

### 2.1 Migrate to Shared Framework (Optional but Recommended)

Create `SilentXLibrary` framework target for code shared between app and extension:

**Shared Code**:
- Models (Profile, ProxyNode, RoutingRule, CoreVersion)
- Services (ConfigurationService, ProfileService)
- Database (SwiftData models, SharedPreferences)
- FilePath, Constants

**Benefits**:
- Clean separation of concerns
- Avoid code duplication
- Easier testing

### 2.2 Database Migration to GRDB (Required for Extension)

**Why**: SwiftData doesn't work well in Network Extensions (sandbox limitations)

**Migration Path**:
```swift
// Current: SwiftData
@Model
class Profile {
    var id: UUID
    var name: String
    // ...
}

// Target: GRDB
import GRDB

class Profile: Record {
    var id: Int64?
    var name: String
    // ...

    override class var databaseTableName: String { "profiles" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
    }
}
```

**Migration Script**:
```swift
struct DatabaseMigrator {
    static func migrate() {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "profiles") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("configurationJSON", .text).notNull()
                t.column("type", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
                // ... other columns
            }

            try db.create(table: "preferences") { t in
                t.primaryKey("name", .text, onConflict: .replace).notNull()
                t.column("data", .blob)
            }
        }

        try migrator.migrate(Database.sharedWriter)
    }
}
```

**File**: `SilentX/Services/Database.swift`

### 2.3 Implement SharedPreferences (IPC)

**Purpose**: Share settings between app and extension via database

```swift
// SilentX/Services/SharedPreferences.swift
public enum SharedPreferences {
    // Core settings
    public static let selectedProfileID = Preference<Int64>("selected_profile_id", defaultValue: -1)
    public static let systemProxyEnabled = Preference<Bool>("system_proxy_enabled", defaultValue: true)
    public static let includeAllNetworks = Preference<Bool>("include_all_networks", defaultValue: false)
    public static let autoRoute = Preference<Bool>("auto_route", defaultValue: true)

    // Performance
    public static let ignoreMemoryLimit = Preference<Bool>("ignore_memory_limit", defaultValue: false)

    // Preferences implementation
    public class Preference<T: Codable> {
        let name: String
        private let defaultValue: T

        init(_ name: String, defaultValue: T) {
            self.name = name
            self.defaultValue = defaultValue
        }

        public func get() async -> T {
            do {
                return try await SharedPreferences.read(name) ?? defaultValue
            } catch {
                NSLog("read preferences error: \(error)")
                return defaultValue
            }
        }

        public func set(_ newValue: T?) async {
            do {
                try await SharedPreferences.write(name, newValue)
            } catch {
                NSLog("write preferences error: \(error)")
            }
        }
    }

    private static func read<T: Codable>(_ name: String) async throws -> T? {
        guard let item = try await Database.sharedWriter.read({ db in
            try PreferenceItem.fetchOne(db, key: name)
        }) else {
            return nil
        }
        if T.self == String.self {
            return String(data: item.data, encoding: .utf8) as? T
        } else {
            return try JSONDecoder().decode(T.self, from: item.data)
        }
    }

    private static func write<T: Codable>(_ name: String, _ value: T?) async throws {
        try await Database.sharedWriter.write { db in
            if let value {
                let data: Data
                if let stringValue = value as? String {
                    data = stringValue.data(using: .utf8)!
                } else {
                    data = try JSONEncoder().encode(value)
                }
                let item = PreferenceItem(name: name, data: data)
                try item.save(db)
            } else {
                try PreferenceItem.deleteOne(db, key: name)
            }
        }
    }
}

struct PreferenceItem: Codable, FetchableRecord, PersistableRecord {
    var name: String
    var data: Data

    static let databaseTableName = "preferences"
}
```

---

## Phase 3: Network Extension Implementation

### 3.1 ExtensionProvider Base Class

**File**: `SilentXExtension/ExtensionProvider.swift`

```swift
import Foundation
import NetworkExtension
import Libbox

/// Base class for Network Extension providers
/// Manages sing-box core lifecycle and platform integration
open class ExtensionProvider: NEPacketTunnelProvider {

    // MARK: - Properties

    var commandServer: LibboxCommandServer?
    var platformInterface: ExtensionPlatformInterface?
    private var startTime: Date?

    // MARK: - Lifecycle

    override open func startTunnel(options: [String: NSObject]?) async throws {
        startTime = Date()
        writeMessage("Extension starting...")

        // 1. Initialize Libbox environment
        try setupLibbox()

        // 2. Create platform interface
        if platformInterface == nil {
            platformInterface = ExtensionPlatformInterface(self)
        }

        // 3. Create command server for IPC
        var error: NSError?
        commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &error)
        if let error {
            throw ExtensionError.commandServerFailed(error.localizedDescription)
        }

        try commandServer?.start()
        writeMessage("Command server started")

        // 4. Start sing-box service
        try await startService()

        writeMessage("Extension started successfully (uptime: \(uptime()))")
    }

    override open func stopTunnel(with reason: NEProviderStopReason) async {
        writeMessage("Extension stopping (reason: \(reason))")

        // 1. Stop sing-box service
        stopService()

        // 2. Stop command server
        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
            server.close()
            commandServer = nil
        }

        // 3. Clean up platform interface
        if let platformInterface {
            platformInterface.reset()
        }

        writeMessage("Extension stopped")
    }

    // MARK: - Service Management

    private func startService() async throws {
        // 1. Load selected profile from database
        let profileID = await SharedPreferences.selectedProfileID.get()
        guard profileID > 0 else {
            throw ExtensionError.noProfileSelected
        }

        let profile: Profile?
        do {
            profile = try await Database.sharedWriter.read { db in
                try Profile.fetchOne(db, key: profileID)
            }
        } catch {
            throw ExtensionError.profileLoadFailed(error.localizedDescription)
        }

        guard let profile else {
            throw ExtensionError.profileNotFound(profileID)
        }

        writeMessage("Loaded profile: \(profile.name)")

        // 2. Read configuration JSON
        let configJSON = profile.configurationJSON
        guard !configJSON.isEmpty else {
            throw ExtensionError.emptyConfiguration
        }

        // 3. Start sing-box core with configuration
        let options = LibboxOverrideOptions()

        do {
            try commandServer?.startOrReloadService(configJSON, options: options)
            writeMessage("Service started successfully")
        } catch {
            throw ExtensionError.serviceStartFailed(error.localizedDescription)
        }
    }

    func stopService() {
        do {
            try commandServer?.closeService()
            writeMessage("Service stopped")
        } catch {
            writeMessage("Error stopping service: \(error.localizedDescription)")
        }

        if let platformInterface {
            platformInterface.reset()
        }
    }

    func reloadService() async throws {
        writeMessage("Reloading service...")
        try await startService()
    }

    // MARK: - Libbox Setup

    private func setupLibbox() throws {
        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        options.logMaxLines = 3000

        var error: NSError?
        LibboxSetup(options, &error)
        if let error {
            throw ExtensionError.setupFailed(error.localizedDescription)
        }

        // Redirect stderr for debugging
        var stderrError: NSError?
        LibboxRedirectStderr(
            FilePath.cacheDirectory.appendingPathComponent("stderr.log").relativePath,
            &stderrError
        )

        await LibboxSetMemoryLimit(!SharedPreferences.ignoreMemoryLimit.get())

        writeMessage("Libbox setup complete")
    }

    // MARK: - Utilities

    func writeMessage(_ message: String) {
        NSLog("[SilentX Extension] \(message)")
    }

    private func uptime() -> String {
        guard let startTime else { return "unknown" }
        let interval = Date().timeIntervalSince(startTime)
        let minutes = Int(interval / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Errors

enum ExtensionError: LocalizedError {
    case setupFailed(String)
    case commandServerFailed(String)
    case noProfileSelected
    case profileLoadFailed(String)
    case profileNotFound(Int64)
    case emptyConfiguration
    case serviceStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .setupFailed(let detail):
            return "Libbox setup failed: \(detail)"
        case .commandServerFailed(let detail):
            return "Command server failed: \(detail)"
        case .noProfileSelected:
            return "No profile selected"
        case .profileLoadFailed(let detail):
            return "Failed to load profile: \(detail)"
        case .profileNotFound(let id):
            return "Profile not found: \(id)"
        case .emptyConfiguration:
            return "Configuration is empty"
        case .serviceStartFailed(let detail):
            return "Service start failed: \(detail)"
        }
    }
}
```

### 3.2 ExtensionPlatformInterface (Platform Callbacks)

**File**: `SilentXExtension/ExtensionPlatformInterface.swift`

```swift
import Foundation
import NetworkExtension
import Libbox

/// Platform interface for sing-box core callbacks
/// Implements LibboxPlatformInterfaceProtocol to handle:
/// - TUN interface configuration
/// - Logging
/// - System proxy settings
public class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {

    private weak var tunnel: ExtensionProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?

    init(_ tunnel: ExtensionProvider) {
        self.tunnel = tunnel
    }

    // MARK: - TUN Configuration

    /// Called by sing-box core to configure TUN interface
    public func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [self] in
            try await openTun0(options, ret0_)
        }
    }

    private func openTun0(_ options: LibboxTunOptionsProtocol?, _ ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options else {
            throw NSError(domain: "nil options", code: 0)
        }
        guard let ret0_ else {
            throw NSError(domain: "nil return pointer", code: 0)
        }
        guard let tunnel else {
            throw NSError(domain: "tunnel is nil", code: 0)
        }

        // 1. Create network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            // DNS configuration
            let dnsServer = try options.getDNSServerAddress()
            let dnsSettings = NEDNSSettings(servers: [dnsServer.value])
            dnsSettings.matchDomains = [""]  // Match all domains
            dnsSettings.matchDomainsNoSearch = true
            settings.dnsSettings = dnsSettings

            // IPv4 routes
            var ipv4Address: [String] = []
            var ipv4Mask: [String] = []
            let ipv4AddressIterator = options.getInet4Address()!
            while ipv4AddressIterator.hasNext() {
                let ipv4Prefix = ipv4AddressIterator.next()!
                ipv4Address.append(ipv4Prefix.address())
                ipv4Mask.append(ipv4Prefix.mask())
            }

            let ipv4Settings = NEIPv4Settings(addresses: ipv4Address, subnetMasks: ipv4Mask)

            // Route configuration
            var routes: [NEIPv4Route] = []
            let includeAllNetworks = await SharedPreferences.includeAllNetworks.get()

            if includeAllNetworks {
                routes.append(NEIPv4Route.default())  // 0.0.0.0/0
            } else {
                // Add specific routes from config
                let routeIterator = options.getInet4RouteAddress()!
                while routeIterator.hasNext() {
                    let prefix = routeIterator.next()!
                    routes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                }
            }

            ipv4Settings.includedRoutes = routes
            settings.ipv4Settings = ipv4Settings

            // IPv6 routes (similar to IPv4)
            var ipv6Address: [String] = []
            var ipv6Prefix: [NSNumber] = []
            let ipv6AddressIterator = options.getInet6Address()!
            while ipv6AddressIterator.hasNext() {
                let prefix = ipv6AddressIterator.next()!
                ipv6Address.append(prefix.address())
                ipv6Prefix.append(NSNumber(value: prefix.prefix()))
            }

            if !ipv6Address.isEmpty {
                let ipv6Settings = NEIPv6Settings(addresses: ipv6Address, networkPrefixLengths: ipv6Prefix)

                var ipv6Routes: [NEIPv6Route] = []
                if includeAllNetworks {
                    ipv6Routes.append(NEIPv6Route.default())
                } else {
                    let routeIterator = options.getInet6RouteAddress()!
                    while routeIterator.hasNext() {
                        let prefix = routeIterator.next()!
                        ipv6Routes.append(NEIPv6Route(
                            destinationAddress: prefix.address(),
                            networkPrefixLength: NSNumber(value: prefix.prefix())
                        ))
                    }
                }

                ipv6Settings.includedRoutes = ipv6Routes
                settings.ipv6Settings = ipv6Settings
            }
        }

        // HTTP Proxy settings (THIS IS KEY FOR PORT ISOLATION!)
        if options.isHTTPProxyEnabled() {
            let proxySettings = NEProxySettings()
            let proxyServer = NEProxyServer(
                address: options.getHTTPProxyServer(),
                port: Int(options.getHTTPProxyServerPort())
            )
            proxySettings.httpServer = proxyServer
            proxySettings.httpsServer = proxyServer

            if await SharedPreferences.systemProxyEnabled.get() {
                proxySettings.httpEnabled = true
                proxySettings.httpsEnabled = true
            }

            // Bypass domains
            let bypassIterator = options.getHTTPProxyBypassDomain()!
            var bypassDomains: [String] = []
            while bypassIterator.hasNext() {
                bypassDomains.append(bypassIterator.next())
            }
            proxySettings.exceptionList = bypassDomains

            // Match domains
            let matchIterator = options.getHTTPProxyMatchDomain()!
            var matchDomains: [String] = []
            while matchIterator.hasNext() {
                matchDomains.append(matchIterator.next())
            }
            if !matchDomains.isEmpty {
                proxySettings.matchDomains = matchDomains
            }

            settings.proxySettings = proxySettings
        }

        // 2. Apply network settings
        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        // 3. Return TUN file descriptor to sing-box core
        if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = tunFd
            tunnel.writeMessage("TUN configured successfully (fd: \(tunFd))")
            return
        }

        // Fallback method
        let tunFd = LibboxGetTunnelFileDescriptor()
        if tunFd != -1 {
            ret0_.pointee = tunFd
            tunnel.writeMessage("TUN configured successfully (fd: \(tunFd) via fallback)")
        } else {
            throw NSError(domain: "Failed to get TUN file descriptor", code: 0)
        }
    }

    // MARK: - Logging

    public func writeLog(_ message: String?) {
        guard let message else { return }
        tunnel?.writeMessage(message)
    }

    // MARK: - System Proxy Control

    public func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        guard let networkSettings else { return }
        guard let proxySettings = networkSettings.proxySettings else { return }
        guard proxySettings.httpServer != nil else { return }

        if proxySettings.httpEnabled == isEnabled {
            return
        }

        proxySettings.httpEnabled = isEnabled
        proxySettings.httpsEnabled = isEnabled
        networkSettings.proxySettings = proxySettings

        try runBlocking {
            try await self.tunnel?.setTunnelNetworkSettings(networkSettings)
        }
    }

    // MARK: - Cleanup

    func reset() {
        networkSettings = nil
    }
}

// MARK: - Blocking Helper

func runBlocking<T>(_ work: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>?

    Task {
        do {
            let value = try await work()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    return try result!.get()
}
```

### 3.3 PacketTunnelProvider (Entry Point)

**File**: `SilentXExtension/PacketTunnelProvider.swift`

```swift
import Foundation
import NetworkExtension

/// Network Extension entry point
/// Inherits from ExtensionProvider which handles all core logic
class PacketTunnelProvider: ExtensionProvider {
    // No additional code needed for basic macOS app extension
    // All functionality is in ExtensionProvider base class
}
```

---

## Phase 4: Main App Integration

### 4.1 ExtensionProfile (VPN Manager Wrapper)

**File**: `SilentX/Services/ExtensionProfile.swift`

```swift
import Foundation
import NetworkExtension

/// Manages the VPN connection lifecycle
@MainActor
public class ExtensionProfile: ObservableObject {

    // MARK: - Published Properties

    @Published public var status: ConnectionStatus = .disconnected
    @Published public private(set) var manager: NETunnelProviderManager!

    // MARK: - Initialization

    public init() {}

    // MARK: - Installation (One-time Setup)

    public static func install() async throws {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "SilentX"

        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "Silent-Net.SilentX.extension"
        tunnelProtocol.serverAddress = "sing-box"

        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true

        try await manager.saveToPreferences()
    }

    // MARK: - Load Manager

    public func load() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        if let existing = managers.first {
            manager = existing
        } else {
            // First time - install
            try await Self.install()
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let installed = managers.first else {
                throw ExtensionProfileError.installationFailed
            }
            manager = installed
        }

        // Observe status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusDidChange),
            name: .NEVPNStatusDidChange,
            object: manager.connection
        )

        updateStatus()
    }

    // MARK: - Connection Control

    public func start() async throws {
        guard status.canToggle else {
            throw ExtensionProfileError.invalidState
        }

        if manager == nil {
            try await load()
        }

        manager.isEnabled = true

        // Configure on-demand rules if needed
        // if alwaysOn {
        //     manager.isOnDemandEnabled = true
        //     setOnDemandRules()
        // }

        try await manager.saveToPreferences()
        try manager.connection.startVPNTunnel()

        updateStatus()
    }

    public func stop() async throws {
        guard status.canToggle else {
            throw ExtensionProfileError.invalidState
        }

        manager.connection.stopVPNTunnel()
        updateStatus()
    }

    // MARK: - Status Management

    @objc private func statusDidChange() {
        updateStatus()
    }

    private func updateStatus() {
        switch manager.connection.status {
        case .invalid:
            status = .disconnected
        case .disconnected:
            status = .disconnected
        case .connecting:
            status = .connecting
        case .connected:
            status = .connected(since: Date())  // TODO: Get actual connect time
        case .reasserting:
            status = .connecting
        case .disconnecting:
            status = .disconnecting
        @unknown default:
            status = .disconnected
        }
    }
}

// MARK: - Errors

enum ExtensionProfileError: LocalizedError {
    case installationFailed
    case invalidState

    var errorDescription: String? {
        switch self {
        case .installationFailed:
            return "Failed to install Network Extension"
        case .invalidState:
            return "Cannot change connection state now"
        }
    }
}
```

### 4.2 Update ConnectionService (Real Implementation)

**File**: `SilentX/Services/ConnectionService.swift`

Replace the mock implementation with:

```swift
import Foundation
import Combine
import SwiftData

@MainActor
final class ConnectionService: ConnectionServiceProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var statistics: ConnectionStatistics = .zero

    // MARK: - Private Properties

    private var statisticsTimer: Timer?
    private var lastProfile: Profile?
    private let configurationService: any ConfigurationServiceProtocol
    private let extensionProfile: ExtensionProfile

    // MARK: - Initialization

    init(
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        extensionProfile: ExtensionProfile? = nil
    ) {
        self.configurationService = configurationService ?? ConfigurationService()
        self.extensionProfile = extensionProfile ?? ExtensionProfile()

        // Observe extension status
        self.extensionProfile.$status
            .assign(to: &$status)
    }

    // MARK: - Public Methods

    func connect(profile: Profile) async throws {
        guard status.canToggle else {
            throw ConnectionError.invalidState
        }
        lastProfile = profile

        // 1. Validate configuration
        let validation = configurationService.validate(json: profile.configurationJSON)
        guard validation.isValid else {
            throw ConnectionError.configurationError(validation.errors.first?.message ?? "Invalid configuration")
        }

        // 2. Save selected profile ID to shared preferences
        await SharedPreferences.selectedProfileID.set(profile.id)

        // 3. Start Network Extension
        do {
            try await extensionProfile.start()
        } catch {
            throw ConnectionError.coreError("Failed to start extension: \(error.localizedDescription)")
        }

        // 4. Start statistics timer
        startStatisticsTimer()
    }

    func disconnect() async throws {
        guard status.canToggle else {
            throw ConnectionError.invalidState
        }

        // 1. Stop Network Extension
        try await extensionProfile.stop()

        // 2. Stop statistics timer
        stopStatisticsTimer()
        resetStatistics()
    }

    func restart() async throws {
        if status.isConnected {
            try await disconnect()
        }
        if let profile = lastProfile {
            try await connect(profile: profile)
        } else {
            throw ConnectionError.noActiveProfile
        }
    }

    // MARK: - Private Methods

    private func startStatisticsTimer() {
        // TODO: Get real statistics from CommandClient
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateMockStatistics()
            }
        }
    }

    private func stopStatisticsTimer() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }

    private var mockUploadBytes: Int64 = 0
    private var mockDownloadBytes: Int64 = 0

    private func updateMockStatistics() {
        let uploadDelta = Int64.random(in: 1000...50000)
        let downloadDelta = Int64.random(in: 5000...200000)

        mockUploadBytes += uploadDelta
        mockDownloadBytes += downloadDelta

        statistics = ConnectionStatistics(
            uploadBytes: mockUploadBytes,
            downloadBytes: mockDownloadBytes,
            uploadSpeed: uploadDelta,
            downloadSpeed: downloadDelta,
            connectedDuration: status.connectedDuration
        )
    }

    private func resetStatistics() {
        mockUploadBytes = 0
        mockDownloadBytes = 0
        statistics = .zero
    }
}
```

---

## Phase 5: Entitlements & Provisioning

### 5.1 Main App Entitlements

**File**: `SilentX/SilentX.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Silent-Net.SilentX</string>
    </array>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### 5.2 Extension Entitlements

**File**: `SilentXExtension/SilentXExtension.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Silent-Net.SilentX</string>
    </array>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

### 5.3 Provisioning Profile Setup

**Developer Portal Steps**:

1. **Register App Group**:
   - Go to: Certificates, Identifiers & Profiles → Identifiers → App Groups
   - Create: `group.Silent-Net.SilentX`

2. **Configure Main App Identifier**:
   - Identifier: `Silent-Net.SilentX`
   - Capabilities:
     - Network Extensions
     - App Groups (select `group.Silent-Net.SilentX`)

3. **Configure Extension Identifier**:
   - Identifier: `Silent-Net.SilentX.extension`
   - Capabilities:
     - Network Extensions
     - App Groups (select `group.Silent-Net.SilentX`)

4. **Create Provisioning Profiles**:
   - macOS App Development profile for SilentX
   - macOS App Development profile for SilentXExtension

---

## Phase 6: Testing & Validation

### 6.1 Test Checklist

- [ ] App builds successfully with Libbox framework
- [ ] Extension target builds and links correctly
- [ ] Database migration from SwiftData to GRDB works
- [ ] SharedPreferences can write/read from both app and extension
- [ ] Extension can be installed (ExtensionProfile.install())
- [ ] Extension starts when clicking Connect
- [ ] TUN interface is configured (check with `ifconfig utun3`)
- [ ] Configuration JSON is loaded correctly
- [ ] Sing-box core starts without errors
- [ ] Traffic flows through tunnel
- [ ] Extension stops cleanly
- [ ] No port conflicts with SFM

### 6.2 Debugging Commands

```bash
# Check if extension is running
ps aux | grep SilentXExtension

# Check TUN interface
ifconfig | grep utun

# Monitor extension logs
log stream --predicate 'subsystem == "com.apple.networkextension"' --level debug

# Check VPN status
scutil --nc list

# Force extension crash (for testing recovery)
sudo killall SilentXExtension
```

### 6.3 Configuration Validation

Test with this minimal sing-box config:

```json
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 2080
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "auto_detect_interface": true
  }
}
```

---

## Phase 7: Advanced Features (Optional)

### 7.1 Command Client (Real-time IPC)

Implement `CommandClient` for real-time status updates, logs, and connection tracking.

**File**: `SilentX/Services/CommandClient.swift`

```swift
import Foundation
import Libbox
import Combine

@MainActor
public class CommandClient: ObservableObject {
    @Published public var isConnected: Bool = false
    @Published public var status: LibboxStatusMessage?
    @Published public var logList: [LogEntry] = []

    private var commandClient: LibboxCommandClient?

    public func connect() {
        Task {
            await performConnection()
        }
    }

    private nonisolated func performConnection() async {
        let clientOptions = LibboxCommandClientOptions()
        clientOptions.addCommand(LibboxCommandStatus)
        clientOptions.addCommand(LibboxCommandLog)
        clientOptions.statusInterval = Int64(NSEC_PER_SEC)

        let client = LibboxNewCommandClient(clientHandler(self), clientOptions)!

        // Retry connection up to 10 times
        for i in 0..<10 {
            try? await Task.sleep(nanoseconds: UInt64(Double(100 + (i * 50)) * Double(NSEC_PER_MSEC)))
            do {
                try client.connect()
                await MainActor.run {
                    commandClient = client
                    isConnected = true
                }
                return
            } catch {}
        }
    }

    public func disconnect() {
        try? commandClient?.disconnect()
        commandClient = nil
        isConnected = false
    }
}
```

### 7.2 System Extension Support (Advanced)

For production deployment, consider implementing System Extension support (requires additional entitlements and user approval).

---

## Implementation Timeline

### Week 1: Foundation
- [ ] Day 1-2: Obtain and integrate Libbox.xcframework
- [ ] Day 3-4: Migrate from SwiftData to GRDB
- [ ] Day 5: Implement SharedPreferences and App Groups

### Week 2: Extension Core
- [ ] Day 1-2: Create Network Extension target
- [ ] Day 3-4: Implement ExtensionProvider base class
- [ ] Day 5: Implement ExtensionPlatformInterface

### Week 3: Integration & Testing
- [ ] Day 1-2: Update ConnectionService for real integration
- [ ] Day 3: Implement ExtensionProfile (VPN manager)
- [ ] Day 4-5: Testing and debugging

### Week 4: Polish
- [ ] Day 1-2: Implement CommandClient for real-time IPC
- [ ] Day 3-4: Add error handling and recovery
- [ ] Day 5: Final testing and documentation

---

## Success Criteria

- [ ] App can start/stop Network Extension
- [ ] Sing-box core runs inside extension
- [ ] Configuration is loaded from database
- [ ] TUN interface is configured correctly
- [ ] Traffic flows through tunnel
- [ ] No port conflicts with other apps (SFM)
- [ ] Extension recovers from crashes
- [ ] Clean shutdown without zombie processes

---

## References

- SFM Source: `/Users/xmx/workspace/Silent-Net/RefRepo/sing-box-for-apple`
- Sing-Box Documentation: https://sing-box.sagernet.org/
- Apple NEPacketTunnelProvider: https://developer.apple.com/documentation/networkextension/nepackettunnelprovider
- GRDB Documentation: https://github.com/groue/GRDB.swift

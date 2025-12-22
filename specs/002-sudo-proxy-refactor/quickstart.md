# Quickstart: Dual-Core Proxy Architecture Implementation

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-12 (Updated)

## Overview

This guide provides step-by-step implementation instructions for the dual-core proxy architecture, focusing on **NetworkExtensionEngine** implementation to eliminate password prompts.

---

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| ProxyEngine Protocol | ✅ Complete | `SilentX/Services/Engines/ProxyEngine.swift` |
| LocalProcessEngine | ✅ Complete | Works but requires password on each operation |
| ConnectionService | ✅ Complete | Supports engine switching |
| NetworkExtensionEngine | 🔴 Not Started | **This implementation** |
| System Extension Target | 🔴 Not Started | **This implementation** |

---

## Implementation Steps

### Step 1: Create System Extension Target

**In Xcode**:

1. File → New → Target
2. Select "System Extension"
3. Product Name: `SilentX.System`
4. Bundle Identifier: `Silent-Net.SilentX.System`

**Create directory structure**:
```
SilentX.System/
├── Info.plist
├── main.swift
├── PacketTunnelProvider.swift
├── ExtensionPlatformInterface.swift
└── SilentX.System.entitlements
```

### Step 2: Configure Info.plist for System Extension

**File**: `SilentX.System/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSSystemExtensionUsageDescription</key>
    <string>SilentX needs a system extension to provide VPN functionality.</string>
    <key>NetworkExtension</key>
    <dict>
        <key>NEMachServiceName</key>
        <string>group.Silent-Net.SilentX.system</string>
        <key>NEProviderClasses</key>
        <dict>
            <key>com.apple.networkextension.packet-tunnel</key>
            <string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
        </dict>
    </dict>
</dict>
</plist>
```

### Step 3: Configure Entitlements

**File**: `SilentX.System/SilentX.System.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider-systemextension</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Silent-Net.SilentX</string>
    </array>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Update Main App**: `SilentX/SilentX.entitlements`

```xml
<!-- Add these keys -->
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.Silent-Net.SilentX</string>
</array>
```

### Step 4: Integrate Libbox Framework

**Option A: Download Prebuilt**
```bash
# Download from sing-box releases
curl -L -o Libbox.xcframework.zip https://github.com/SagerNet/sing-box/releases/download/v1.x.x/Libbox-apple-*.xcframework.zip
unzip Libbox.xcframework.zip -d Frameworks/
```

**Option B: Build from Source**
```bash
cd /path/to/sing-box
make build_local_for_apple
cp -r build/Libbox.xcframework /path/to/SilentX/Frameworks/
```

**In Xcode**:
1. Drag `Libbox.xcframework` to project
2. Add to both targets: SilentX and SilentX.System
3. Embed & Sign for SilentX, Do Not Embed for SilentX.System

### Step 5: Implement System Extension Entry Point

**File**: `SilentX.System/main.swift`

```swift
import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}
dispatchMain()
```

### Step 6: Implement PacketTunnelProvider

**File**: `SilentX.System/PacketTunnelProvider.swift`

```swift
import Foundation
import Libbox
import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "Silent-Net.SilentX.System", category: "PacketTunnel")
    private var commandServer: LibboxCommandServer?
    private var platformInterface: ExtensionPlatformInterface?
    private var username: String?
    
    override func startTunnel(options: [String: NSObject]?) async throws {
        logger.info("Starting tunnel...")
        
        // Extract username for path resolution
        guard let usernameObj = options?["username"] as? NSString else {
            throw NSError(domain: "PacketTunnel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing username in options"
            ])
        }
        username = String(usernameObj)
        
        // Setup paths
        let groupContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.Silent-Net.SilentX"
        )!
        let basePath = groupContainer.path
        let workingPath = groupContainer.appendingPathComponent("Working").path
        let tempPath = groupContainer.appendingPathComponent("Cache").path
        
        // Create directories
        try? FileManager.default.createDirectory(atPath: workingPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true)
        
        // Setup Libbox
        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = basePath
        setupOptions.workingPath = workingPath
        setupOptions.tempPath = tempPath
        setupOptions.logMaxLines = 3000
        
        var setupError: NSError?
        LibboxSetup(setupOptions, &setupError)
        if let error = setupError {
            throw error
        }
        
        // Create platform interface
        platformInterface = ExtensionPlatformInterface(self)
        
        // Create command server
        var serverError: NSError?
        commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &serverError)
        if let error = serverError {
            throw error
        }
        
        try commandServer?.start()
        
        // Read config from shared container
        let configPath = groupContainer.appendingPathComponent("active-config.json")
        let configContent = try String(contentsOf: configPath, encoding: .utf8)
        
        // Start service
        let overrideOptions = LibboxOverrideOptions()
        try commandServer?.startOrReloadService(configContent, options: overrideOptions)
        
        logger.info("Tunnel started successfully")
    }
    
    override func stopTunnel(with reason: NEProviderStopReason) async {
        logger.info("Stopping tunnel, reason: \(reason.rawValue)")
        
        try? commandServer?.closeService()
        try? await Task.sleep(nanoseconds: 100_000_000)
        commandServer?.close()
        commandServer = nil
        platformInterface?.reset()
        platformInterface = nil
        
        logger.info("Tunnel stopped")
    }
    
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        // Handle IPC from main app
        messageData
    }
    
    override func sleep() async {
        commandServer?.pause()
    }
    
    override func wake() {
        commandServer?.wake()
    }
}
```

### Step 7: Implement ExtensionPlatformInterface

**File**: `SilentX.System/ExtensionPlatformInterface.swift`

```swift
import Foundation
import Libbox
import NetworkExtension

class ExtensionPlatformInterface: NSObject {
    private weak var provider: NEPacketTunnelProvider?
    private var packetFlow: NEPacketTunnelFlow?
    
    init(_ provider: NEPacketTunnelProvider) {
        self.provider = provider
        super.init()
    }
    
    func reset() {
        packetFlow = nil
    }
}

// MARK: - LibboxPlatformInterface
extension ExtensionPlatformInterface: LibboxPlatformInterfaceProtocol {
    
    func autoDetectInterfaceControl(_ fd: Int32) throws {
        // Not needed for macOS
    }
    
    func openTun(_ options: LibboxTunOptions?) throws -> LibboxTunInterface {
        guard let provider = provider else {
            throw NSError(domain: "Platform", code: 1, userInfo: nil)
        }
        
        // Configure tunnel settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // IPv4
        settings.ipv4Settings = NEIPv4Settings(
            addresses: [options?.inet4Address ?? "172.19.0.1"],
            subnetMasks: ["255.255.255.0"]
        )
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        
        // IPv6
        if let inet6 = options?.inet6Address, !inet6.isEmpty {
            settings.ipv6Settings = NEIPv6Settings(
                addresses: [inet6],
                networkPrefixLengths: [128]
            )
            settings.ipv6Settings?.includedRoutes = [NEIPv6Route.default()]
        }
        
        // DNS
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        
        // MTU
        settings.mtu = NSNumber(value: options?.mtu ?? 9000)
        
        // Apply settings
        let semaphore = DispatchSemaphore(value: 0)
        var setError: Error?
        
        provider.setTunnelNetworkSettings(settings) { error in
            setError = error
            semaphore.signal()
        }
        semaphore.wait()
        
        if let error = setError {
            throw error
        }
        
        packetFlow = provider.packetFlow
        return TunInterface(flow: provider.packetFlow)
    }
    
    func useProcFS() -> Bool { false }
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32) throws -> Int32 { -1 }
    func packageNameByUid(_ uid: Int32) throws -> String { "" }
    func uidByPackageName(_ packageName: String?) throws -> Int32 { -1 }
    func usePlatformAutoDetectInterfaceControl() -> Bool { false }
    func usePlatformDefaultInterfaceMonitor() -> Bool { false }
    func usePlatformInterfaceGetter() -> Bool { false }
    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol { EmptyIterator() }
    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    func clearDNSCache() {}
    func readWIFIState() throws -> LibboxWIFIState { LibboxWIFIState() }
}

// MARK: - LibboxCommandServerHandler
extension ExtensionPlatformInterface: LibboxCommandServerHandlerProtocol {
    func serviceReload() throws {
        // Handle reload
    }
    
    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        LibboxSystemProxyStatus()
    }
    
    func setSystemProxyEnabled(_ enabled: Bool) throws {
        // Handle system proxy toggle
    }
    
    func postServiceClose() {
        // Cleanup after service close
    }
    
    func writeMessage(_ level: Int32, message: String?) {
        guard let message = message else { return }
        NSLog("[Libbox L\(level)] \(message)")
    }
    
    func writeGroups(_ message: LibboxOutboundGroupIteratorProtocol?) {
        // Handle group updates
    }
    
    func writeNetwork(_ message: LibboxNetworkStatusProtocol?) {
        // Handle network status updates
    }
}

// MARK: - Helper Classes
private class TunInterface: NSObject, LibboxTunInterfaceProtocol {
    private let flow: NEPacketTunnelFlow
    
    init(flow: NEPacketTunnelFlow) {
        self.flow = flow
        super.init()
    }
    
    func read(_ p0: Data?) throws -> Int {
        // Read packets
        return 0
    }
    
    func write(_ p0: Data?) throws -> Int {
        // Write packets
        return p0?.count ?? 0
    }
    
    func close() throws {
        // Close
    }
    
    func fd() -> Int32 { -1 }
}

private class EmptyIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    func hasNext() -> Bool { false }
    func next() -> LibboxNetworkInterface? { nil }
}
```

### Step 8: Implement Main App Components

**File**: `SilentX/Services/Engines/SystemExtension.swift`

```swift
#if os(macOS)
import Foundation
import SystemExtensions

public class SystemExtension: NSObject, OSSystemExtensionRequestDelegate {
    private let forceUpdate: Bool
    private let inBackground: Bool
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: OSSystemExtensionRequest.Result?
    private var properties: [OSSystemExtensionProperties]?
    private var error: Error?
    
    private init(_ forceUpdate: Bool = false, _ inBackground: Bool = false) {
        self.forceUpdate = forceUpdate
        self.inBackground = inBackground
    }
    
    // ... (implementation from contracts/system-extension.md)
    
    public static func isInstalled() async -> Bool {
        await (try? Task {
            try await isInstalledBackground()
        }.result.get()) == true
    }
    
    public static func install(forceUpdate: Bool = false, inBackground: Bool = false) async throws -> OSSystemExtensionRequest.Result? {
        try await Task.detached {
            try SystemExtension(forceUpdate, inBackground).activation()
        }.result.get()
    }
}
#endif
```

**File**: `SilentX/Services/Engines/ExtensionProfile.swift`

```swift
import Foundation
import NetworkExtension
import Combine

public class ExtensionProfile: ObservableObject {
    private let manager: NEVPNManager
    
    @Published public var status: NEVPNStatus
    @Published public var connectedDate: Date?
    
    private var observer: Any?
    
    public init(_ manager: NEVPNManager) {
        self.manager = manager
        self.status = manager.connection.status
        self.connectedDate = manager.connection.connectedDate
    }
    
    public func register() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            self.status = (notification.object as? NEVPNConnection)?.status ?? .invalid
            self.connectedDate = (notification.object as? NEVPNConnection)?.connectedDate
        }
    }
    
    public func start() async throws {
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try manager.connection.startVPNTunnel(options: [
            "username": NSString(string: NSUserName())
        ])
    }
    
    public func stop() async throws {
        manager.connection.stopVPNTunnel()
    }
    
    public static func load() async throws -> ExtensionProfile? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let first = managers.first else { return nil }
        return ExtensionProfile(first)
    }
    
    public static func install() async throws {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "SilentX"
        
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "Silent-Net.SilentX.System"
        tunnelProtocol.serverAddress = "sing-box"
        
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true
        
        try await manager.saveToPreferences()
    }
}
```

**File**: `SilentX/Services/Engines/NetworkExtensionEngine.swift`

```swift
import Foundation
import Combine
import NetworkExtension

@MainActor
final class NetworkExtensionEngine: ProxyEngine {
    
    private let statusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private var profile: ExtensionProfile?
    private var statusObserver: AnyCancellable?
    
    var status: ConnectionStatus { statusSubject.value }
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { statusSubject.eraseToAnyPublisher() }
    let engineType: EngineType = .networkExtension
    
    func start(config: ProxyConfiguration) async throws {
        guard status == .disconnected else {
            throw ProxyError.unknown("Already connected")
        }
        
        statusSubject.send(.connecting)
        
        // Check system extension
        guard await SystemExtension.isInstalled() else {
            statusSubject.send(.error(.extensionNotInstalled))
            throw ProxyError.extensionNotInstalled
        }
        
        // Write config to shared container
        let groupContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.Silent-Net.SilentX"
        )!
        let configDest = groupContainer.appendingPathComponent("active-config.json")
        let configContent = try String(contentsOf: config.configPath, encoding: .utf8)
        try configContent.write(to: configDest, atomically: true, encoding: .utf8)
        
        // Load or install profile
        profile = try await ExtensionProfile.load()
        if profile == nil {
            try await ExtensionProfile.install()
            profile = try await ExtensionProfile.load()
        }
        
        guard let profile else {
            throw ProxyError.extensionLoadFailed("Cannot load VPN profile")
        }
        
        // Observe status
        profile.register()
        statusObserver = profile.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] neStatus in
                self?.handleNEStatusChange(neStatus)
            }
        
        // Start tunnel
        try await profile.start()
    }
    
    func stop() async throws {
        statusSubject.send(.disconnecting)
        statusObserver?.cancel()
        try await profile?.stop()
        profile = nil
        statusSubject.send(.disconnected)
    }
    
    func validate(config: ProxyConfiguration) async -> [ProxyError] {
        var errors: [ProxyError] = []
        
        if !await SystemExtension.isInstalled() {
            errors.append(.extensionNotInstalled)
        }
        
        if !FileManager.default.fileExists(atPath: config.configPath.path) {
            errors.append(.configNotFound)
        }
        
        return errors
    }
    
    private func handleNEStatusChange(_ neStatus: NEVPNStatus) {
        switch neStatus {
        case .connected:
            statusSubject.send(.connected(ConnectionInfo(
                engineType: .networkExtension,
                startTime: profile?.connectedDate ?? Date(),
                configName: "Active Profile",
                listenPorts: []
            )))
        case .connecting, .reasserting:
            statusSubject.send(.connecting)
        case .disconnecting:
            statusSubject.send(.disconnecting)
        case .disconnected, .invalid:
            statusSubject.send(.disconnected)
        @unknown default:
            break
        }
    }
}
```

### Step 9: Update ProxyError

**File**: `SilentX/Services/Engines/ProxyError.swift`

Add new cases:
```swift
case extensionNotInstalled
case extensionLoadFailed(String)
case tunnelStartFailed(String)
```

### Step 10: Update ConnectionService

Update to support NetworkExtensionEngine:

```swift
func connect(profile: Profile) async throws {
    let engine: any ProxyEngine
    switch profile.preferredEngine {
    case .localProcess:
        engine = LocalProcessEngine()
    case .networkExtension:
        engine = NetworkExtensionEngine()  // Now implemented!
    }
    // ... rest of connection logic
}
```

---

## Testing Checklist

### System Extension

- [ ] Extension builds successfully
- [ ] Extension installs via System Preferences approval
- [ ] `SystemExtension.isInstalled()` returns true after approval
- [ ] Extension uninstalls correctly

### VPN Profile

- [ ] VPN profile appears in System Preferences → Network
- [ ] Profile starts tunnel without password prompt
- [ ] Profile stops tunnel correctly

### Full Flow

- [ ] User clicks Connect → tunnel starts (no password)
- [ ] User clicks Disconnect → tunnel stops (no password)
- [ ] Status updates correctly in UI
- [ ] Config changes apply on next connect

---

## Build Commands

```bash
# Build all targets
xcodebuild -scheme SilentX -configuration Debug -destination 'platform=macOS' build

# Sign for testing (development)
codesign --force --deep --sign "Apple Development" SilentX.app
codesign --force --deep --sign "Apple Development" SilentX.app/Contents/Library/SystemExtensions/SilentX.System.systemextension
```

---

## Troubleshooting

### Extension Not Installing

1. Check Console.app for `sysextd` logs
2. Verify entitlements match between Info.plist and .entitlements
3. Ensure app is in /Applications (not ~/Applications)

### Tunnel Not Starting

1. Check Console.app for PacketTunnel logs
2. Verify config is written to shared container
3. Check Libbox initialization errors

### Status Not Updating

1. Verify `NEVPNStatusDidChange` observer is registered
2. Check that profile is retained during connection
3. Verify main actor dispatch for UI updates

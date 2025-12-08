# Real Core Integration Implementation Guide

**Created**: 2025-12-06
**Purpose**: Transition from mock implementation to real Sing-Box core integration
**Based on**: SFM (Sing-Box for Apple) reference implementation

## Current State vs. Target State

### Current (Mock) Implementation
- ✅ UI/UX complete and working
- ✅ Profile management (SwiftData)
- ✅ Configuration validation
- ❌ No actual network proxy functionality
- ❌ Just simulates connection state changes

### Target (Real) Implementation
- ✅ All current features preserved
- ✅ Real Sing-Box core integration via Libbox framework
- ✅ macOS Network Extension for system-wide VPN
- ✅ Actual proxy/routing based on configuration
- ✅ Real-time statistics and logging

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      SilentX.app                            │
│  ┌────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ SwiftUI    │  │ Connection   │  │ NETunnelProvider    │ │
│  │ Views      │→ │ Service      │→ │ Manager             │ │
│  └────────────┘  └──────────────┘  └─────────────────────┘ │
│                                              ↓               │
└──────────────────────────────────────────────┼───────────────┘
                                               │ XPC/IPC
┌──────────────────────────────────────────────┼───────────────┐
│         Network Extension (Separate Process) ↓               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ PacketTunnelProvider (NEPacketTunnelProvider)       │    │
│  │  - startTunnel()                                    │    │
│  │  - stopTunnel()                                     │    │
│  └───────────────────┬─────────────────────────────────┘    │
│                      ↓                                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ ExtensionPlatformInterface                          │    │
│  │  - openTun() → Creates TUN interface               │    │
│  │  - Implements LibboxPlatformInterfaceProtocol      │    │
│  └───────────────────┬─────────────────────────────────┘    │
│                      ↓                                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Libbox Framework (Sing-Box Go Library)             │    │
│  │  - LibboxNewCommandServer()                        │    │
│  │  - LibboxStartService()                            │    │
│  │  - Handles all proxy/routing logic                 │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│               macOS Network Stack                            │
│  All system traffic routed through TUN interface            │
└──────────────────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Libbox Framework Integration (Prerequisite)

**Goal**: Add pre-compiled Libbox framework to project

**Steps**:

1. **Obtain Libbox Framework**
   - Option A: Build from source (requires Go toolchain)
     ```bash
     cd /Users/xmx/workspace/Silent-Net/RefRepo/sing-box
     make lib
     ```
   - Option B: Copy from SFM reference
     ```bash
     cp -R /Users/xmx/workspace/Silent-Net/RefRepo/sing-box-for-apple/Frameworks/Libbox.xcframework \
           /Users/xmx/workspace/Silent-Net/SilentX/Frameworks/
     ```

2. **Add to Xcode Project**
   - Open SilentX.xcodeproj
   - Add Libbox.xcframework to Frameworks
   - Set "Embed & Sign" for main app target
   - Set "Do Not Embed" for extension target (will be added separately)

3. **Verify Import**
   - Create test file to verify `import Libbox` works
   - Check that Libbox types are accessible

**Deliverable**: Libbox framework properly linked and importable

---

### Phase 2: Network Extension Target Setup

**Goal**: Create Network Extension target in Xcode

**Steps**:

1. **Create Extension Target**
   - File → New → Target → Network Extension
   - Name: "SilentXExtension"
   - Bundle ID: `io.silentnet.SilentX.extension`
   - Deployment target: macOS 14.0

2. **Configure Entitlements**
   - Enable Network Extension capability
   - Add App Groups: `group.io.silentnet.SilentX`
   - Required entitlements:
     ```xml
     <key>com.apple.developer.networking.networkextension</key>
     <array>
         <string>packet-tunnel-provider</string>
     </array>
     <key>com.apple.security.application-groups</key>
     <array>
         <string>group.io.silentnet.SilentX</string>
     </array>
     ```

3. **Configure Info.plist**
   - Add `NEMachServiceName`: `$(TeamIdentifierPrefix)io.silentnet.SilentX.extension`
   - Add `NSExtension` configuration

4. **Update Main App Entitlements**
   - Add same App Groups capability
   - Add Network Extension entitlement

**Deliverable**: Network Extension target created and configured

---

### Phase 3: Shared Infrastructure

**Goal**: Create shared code accessible by both app and extension

**Files to Create**:

1. **`SilentX/Shared/FilePath.swift`** (shared between app and extension)
   ```swift
   import Foundation

   public struct FilePath {
       public static let packageName = "io.silentnet.SilentX"
       public static let groupIdentifier = "group.io.silentnet.SilentX"

       public static var sharedDirectory: URL {
           FileManager.default.containerURL(
               forSecurityApplicationGroupIdentifier: groupIdentifier
           )!
       }

       public static var workingDirectory: URL {
           sharedDirectory.appendingPathComponent("Library/Application Support")
       }

       public static var cacheDirectory: URL {
           sharedDirectory.appendingPathComponent("Library/Caches")
       }

       public static func profilePath(for id: UUID) -> URL {
           workingDirectory.appendingPathComponent("profiles/\(id.uuidString).json")
       }
   }
   ```

2. **Update SwiftData Configuration**
   - Move model container to shared App Group directory
   - Both app and extension can access profiles

**Deliverable**: Shared infrastructure for data access

---

### Phase 4: Extension Provider Implementation

**Goal**: Implement core Network Extension logic

**Files to Create**:

1. **`SilentXExtension/PacketTunnelProvider.swift`**
   ```swift
   import NetworkExtension
   import Libbox

   class PacketTunnelProvider: NEPacketTunnelProvider {
       private var commandServer: LibboxCommandServer?
       private var platformInterface: PlatformInterface?

       override func startTunnel(options: [String : NSObject]?) async throws {
           // 1. Setup Libbox
           let setupOptions = LibboxSetupOptions()
           setupOptions.basePath = FilePath.sharedDirectory.path
           setupOptions.workingPath = FilePath.workingDirectory.path
           setupOptions.tempPath = FilePath.cacheDirectory.path

           var error: NSError?
           LibboxSetup(setupOptions, &error)
           if let error = error {
               throw error
           }

           // 2. Create platform interface
           platformInterface = PlatformInterface(self)

           // 3. Create command server
           commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &error)
           if let error = error {
               throw error
           }

           try commandServer?.start()

           // 4. Load and start service
           try await startService()
       }

       private func startService() async throws {
           // Load active profile from SwiftData
           // Read configuration JSON
           // Start sing-box core via commandServer
       }

       override func stopTunnel(with reason: NEProviderStopReason) async {
           try? commandServer?.closeService()
           try? await Task.sleep(nanoseconds: 100_000_000)
           commandServer?.close()
           commandServer = nil
       }
   }
   ```

2. **`SilentXExtension/PlatformInterface.swift`**
   - Implement `LibboxPlatformInterfaceProtocol`
   - Key method: `openTun()` - creates TUN interface
   - Based on SFM's `ExtensionPlatformInterface.swift` (already analyzed)

**Deliverable**: Working Network Extension that can start/stop

---

### Phase 5: App-Side Integration (Update ConnectionService)

**Goal**: Replace mock implementation with real Network Extension control

**File to Modify**: `SilentX/Services/ConnectionService.swift`

**Changes**:

```swift
import NetworkExtension

@MainActor
final class ConnectionService: ConnectionServiceProtocol, ObservableObject {
    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var statistics: ConnectionStatistics = .zero

    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: Any?
    private let configurationService: any ConfigurationServiceProtocol

    init(configurationService: (any ConfigurationServiceProtocol)? = nil) {
        self.configurationService = configurationService ?? ConfigurationService()
        setupStatusObserver()
    }

    func connect(profile: Profile) async throws {
        // 1. Validate configuration
        let validation = configurationService.validate(json: profile.configurationJSON)
        guard validation.isValid else {
            throw ConnectionError.configurationError(validation.errors.first?.message ?? "Invalid")
        }

        // 2. Save as active profile (extension will read this)
        try await saveActiveProfile(profile)

        // 3. Load or install tunnel manager
        if tunnelManager == nil {
            tunnelManager = try await loadOrInstallTunnelManager()
        }

        // 4. Start VPN tunnel
        status = .connecting
        try tunnelManager?.connection.startVPNTunnel()

        // Status updates will come via notification observer
    }

    func disconnect() async throws {
        tunnelManager?.connection.stopVPNTunnel()
        status = .disconnecting
    }

    private func loadOrInstallTunnelManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        if let existing = managers.first {
            return existing
        }

        // Install new configuration
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "SilentX"

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "io.silentnet.SilentX.extension"
        proto.serverAddress = "sing-box"
        manager.protocolConfiguration = proto
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        return manager
    }

    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let connection = notification.object as? NEVPNConnection else {
                return
            }

            self.updateStatus(from: connection.status)
        }
    }

    private func updateStatus(from vpnStatus: NEVPNStatus) {
        switch vpnStatus {
        case .invalid, .disconnected:
            status = .disconnected
        case .connecting:
            status = .connecting
        case .connected:
            status = .connected(since: Date())
        case .reasserting:
            status = .connecting
        case .disconnecting:
            status = .disconnecting
        @unknown default:
            break
        }
    }
}
```

**Deliverable**: ConnectionService controls real Network Extension

---

### Phase 6: Real-Time Statistics & Logging

**Goal**: Add real statistics and log streaming from extension

**Implementation**:

1. **Add CommandClient Integration**
   - Create `CommandClient` wrapper (based on SFM)
   - Connect to extension's command server
   - Stream status updates, logs, connection stats

2. **Update StatisticsView**
   - Replace mock data with real statistics from CommandClient
   - Update upload/download counters from actual traffic

3. **Update LogService**
   - Stream real logs from extension
   - Display core startup, connection events, errors

**Deliverable**: Real-time stats and logs working

---

## Testing Strategy

### Phase Testing

Each phase should be tested independently:

1. **Phase 1**: Verify Libbox framework imports without errors
2. **Phase 2**: Build succeeds, extension target runs
3. **Phase 3**: App and extension can both access shared profile data
4. **Phase 4**: Extension starts without crashing, creates TUN interface
5. **Phase 5**: App successfully starts/stops extension
6. **Phase 6**: Stats and logs display correctly

### Integration Testing

1. **Connection Flow**
   - Import a valid profile
   - Click Connect
   - Verify system proxy settings change
   - Test actual network traffic routes through proxy
   - Click Disconnect
   - Verify traffic returns to normal

2. **Error Handling**
   - Test with invalid configuration
   - Test with unreachable proxy server
   - Test rapid connect/disconnect
   - Test app quit while connected

## Entitlements & Provisioning

### Required Capabilities

1. **App Target**
   - Network Extension
   - App Groups: `group.io.silentnet.SilentX`

2. **Extension Target**
   - Network Extension (Packet Tunnel Provider)
   - App Groups: `group.io.silentnet.SilentX`

### Provisioning Profile

- **Development**: Ad-hoc signing may work
- **Distribution**: Requires Apple Developer account with:
  - Network Extension entitlement approval
  - App Groups capability
  - Provisioning profiles for both targets

## Common Issues & Solutions

### Issue 1: "Extension process crashes immediately"

**Cause**: Libbox framework not properly embedded or signed
**Solution**: Verify framework is in extension's "Embed Frameworks" and code signing is correct

### Issue 2: "Cannot access shared container"

**Cause**: App Group identifier mismatch
**Solution**: Ensure exact same group ID in both targets' entitlements

### Issue 3: "Permission denied for Network Extension"

**Cause**: Missing entitlements or not properly signed
**Solution**: Check provisioning profile includes Network Extension capability

### Issue 4: "Extension starts but no traffic flows"

**Cause**: TUN interface not created properly
**Solution**: Check `openTun()` implementation, verify DNS and routing settings

## Migration Path from Mock to Real

To minimize disruption:

1. **Keep mock as fallback**: Add feature flag
   ```swift
   struct FeatureFlags {
       static let useRealCore = true  // Toggle for testing
   }
   ```

2. **Gradual rollout**: Test with small subset of profiles first

3. **Preserve UI/UX**: All existing views continue to work unchanged

## Next Steps

1. ✅ Read this guide
2. ☐ Decide: Build Libbox from source or use pre-built framework?
3. ☐ Start with Phase 1: Libbox framework integration
4. ☐ Proceed through phases sequentially
5. ☐ Test thoroughly at each phase
6. ☐ Ask questions if anything is unclear!

## References

- SFM Source: `/Users/xmx/workspace/Silent-Net/RefRepo/sing-box-for-apple`
- Sing-Box Docs: https://sing-box.sagernet.org/
- Apple Network Extension: https://developer.apple.com/documentation/networkextension
- Post-MVP Tasks in tasks.md: T124-T139

---

**Questions?** Feel free to ask about any phase or concept!

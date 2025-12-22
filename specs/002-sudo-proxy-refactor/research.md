# Research: Dual-Core Proxy Architecture (双内核模式)

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-12 (Updated)
**Status**: Complete

## Research Questions

1. How to implement macOS privilege escalation for launching sing-box with root permissions?
2. How does sing-box for apple (SFM) implement TUN mode?
3. What architecture should we use: SMJobBless helper vs Network Extension?
4. **NEW**: How to avoid repeated password prompts for LocalProcessEngine (sudo mode)?

---

## Decision 1: Privilege Escalation Approach (Updated)

### Decision: Dual-Engine Architecture

| Engine | Purpose | UX |
|--------|---------|-----|
| **NetworkExtensionEngine** | TUN mode, full VPN routing | One-time system extension approval, then password-free |
| **LocalProcessEngine** | HTTP/SOCKS proxy, dev/debug | Either SMJobBless helper OR sudo-with-caching |

### Key Insight from SFM

After deep analysis of `/RefRepo/sing-box-for-apple`:

1. **SFM uses System Extension** (`SFM.System`) with `NEPacketTunnelProvider`
2. **No sudo passwords at all** - macOS handles extension approval once
3. **Extension runs as separate process** managed by launchd
4. Uses **Libbox** (Go-compiled library) inside extension for sing-box core

### How SFM Works (Architecture)

```
┌─────────────────────────────────────────────────────────────────┐
│                    SFM (Main App - Sandboxed)                   │
├─────────────────────────────────────────────────────────────────┤
│  ExtensionProfile                                                │
│    ├── NETunnelProviderManager (loadAllFromPreferences)         │
│    ├── manager.connection.startVPNTunnel(options:)              │
│    └── manager.connection.stopVPNTunnel()                        │
│                                                                  │
│  ExtensionEnvironments                                           │
│    ├── Observes NEVPNStatus notifications                        │
│    └── Publishes status to UI                                    │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ IPC via NetworkExtension framework
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│            SFM.System (System Extension - Not Sandboxed)        │
├─────────────────────────────────────────────────────────────────┤
│  PacketTunnelProvider : NEPacketTunnelProvider                  │
│    ├── startTunnel(options:) -> reads config from App Group     │
│    ├── LibboxNewService(config, platformInterface)              │
│    ├── service.start() -> creates TUN, runs sing-box            │
│    └── stopTunnel(reason:) -> service.close()                   │
│                                                                  │
│  ExtensionPlatformInterface                                      │
│    ├── Implements Libbox callbacks                               │
│    └── Handles TUN packet I/O                                    │
└──────────────────────────────────────────────────────────────────┘
```

### Key Files in SFM Reference

| File | Purpose |
|------|---------|
| `Library/Network/ExtensionProfile.swift` | `start()`, `stop()` via NETunnelProviderManager |
| `Library/Network/ExtensionProvider.swift` | Base `NEPacketTunnelProvider` with Libbox integration |
| `Library/Network/SystemExtension.swift` | System extension install/uninstall via `OSSystemExtensionRequest` |
| `SystemExtension/PacketTunnelProvider.swift` | macOS entry point, sets up paths |
| `SystemExtension/Info.plist` | `NEMachServiceName`, `NEProviderClasses` |
| `SystemExtension/SystemExtension.entitlements` | `packet-tunnel-provider-systemextension` |

---

## Decision 2: Solving Repeated Password Prompts (NEW)

### Problem

Current LocalProcessEngine uses AppleScript `do shell script with administrator privileges` for every connect AND disconnect. This is terrible UX:
- Password prompt on connect
- Password prompt on disconnect
- User fatigue → poor adoption

### Solution Options Analyzed

| Approach | Connect | Disconnect | Complexity | App Store |
|----------|---------|------------|------------|-----------|
| **A: SMJobBless Helper** | No prompt after first | No prompt | High | Yes |
| **B: sudo -n with cached credentials** | Prompt every 5 min | Fast path with -n | Low | No |
| **C: Network Extension** | System approval once | No prompt | Medium | Yes |
| **D: Keep current AppleScript** | Prompt every time | Prompt every time | None | No |

### Decision: Implement Option C (NetworkExtensionEngine) as Primary

**Rationale:**
1. **SFM proves it works** - this is the production-tested approach
2. **Best UX** - one-time system extension approval, then passwordless forever
3. **App Store compatible** - required for distribution
4. **Full TUN support** - HTTP/SOCKS AND system-wide VPN routing

### Fallback: Keep LocalProcessEngine for Development

For users who don't want system extension or for debugging:
- Continue using current sudo approach
- Accept the password prompts as "dev mode" cost
- Maybe add `sudo -n` fast-path for cached credentials (already partially done)

---

## Decision 3: Architecture for Hybrid Mode Support (Confirmed)

### Decision: Protocol-based ProxyEngine abstraction with two implementations

```swift
protocol ProxyEngine {
    func start(config: ProxyConfiguration) async throws
    func stop() async throws
    var status: ConnectionStatus { get }
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { get }
    var engineType: EngineType { get }
}

// Implementation 1: Network Extension (RECOMMENDED)
class NetworkExtensionEngine: ProxyEngine {
    // Uses NETunnelProviderManager to control system extension
    // NO password prompts after initial approval
    // Full TUN support
    // App Store compatible
}

// Implementation 2: Local Process (for dev/debug)
class LocalProcessEngine: ProxyEngine {
    // Current approach - launches sing-box via sudo
    // Password prompts on connect/disconnect
    // HTTP/SOCKS only (TUN requires sudo every time)
    // NOT App Store compatible
}
```

### Mode Comparison (Updated)

| Feature | LocalProcessEngine | NetworkExtensionEngine |
|---------|-------------------|----------------------|
| HTTP/SOCKS Proxy | ✅ Yes | ✅ Yes |
| TUN Mode | ⚠️ Requires sudo | ✅ Yes (native) |
| Password Prompt | ❌ Every connect/disconnect | ✅ None after approval |
| System Extension | Not needed | Required once |
| App Store | ❌ No | ✅ Yes |
| Complexity | Low | Medium |
| Debug Friendly | ✅ Yes | ⚠️ Need console.app |

---

## Decision 4: Implementation Phasing (Revised)

### Phase 1: LocalProcessEngine (DONE ✅)
Current state - working but with password prompts on every operation.

### Phase 2: NetworkExtensionEngine Implementation (THIS ITERATION)

**Goal**: Implement full Network Extension support following SFM pattern.

#### 2.1 Create System Extension Target

```
SilentX.System/
├── Info.plist
├── main.swift (or @main struct)
├── PacketTunnelProvider.swift
└── SilentX.System.entitlements
```

#### 2.2 Integrate Libbox

Options:
1. **Build from source** - Use `make build_for_apple` in sing-box repo
2. **Use prebuilt XCFramework** - Download from sing-box releases

#### 2.3 Implement NetworkExtensionEngine

```swift
// SilentX/Services/Engines/NetworkExtensionEngine.swift
final class NetworkExtensionEngine: ProxyEngine {
    private var profile: ExtensionProfile?
    
    func start(config: ProxyConfiguration) async throws {
        // 1. Check if system extension installed
        // 2. Write config to App Group shared container
        // 3. Call profile.start() -> startVPNTunnel()
    }
    
    func stop() async throws {
        // Call profile.stop() -> stopVPNTunnel()
    }
}
```

#### 2.4 System Extension Installation UI

Add to Settings:
- "Install System Extension" button
- Status indicator (installed/pending/not installed)
- Follow SFM's `InstallSystemExtensionButton` pattern

---

## Technical Details: Network Extension Implementation

### Required Entitlements (Main App - SilentX.entitlements)

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.Silent-Net.SilentX</string>
</array>
```

### Required Entitlements (System Extension - SilentX.System.entitlements)

```xml
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
```

### System Extension Info.plist

```xml
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
```

### Key APIs (from SFM Reference)

```swift
// ExtensionProfile.swift - Starting tunnel
public func start() async throws {
    await fetchProfile()
    manager.isEnabled = true
    try await manager.saveToPreferences()
    try manager.connection.startVPNTunnel(options: [
        "username": NSString(string: NSUserName())  // For path resolution
    ])
}

// ExtensionProfile.swift - Stopping tunnel
public func stop() async throws {
    if manager.isOnDemandEnabled {
        manager.isOnDemandEnabled = false
        try await manager.saveToPreferences()
    }
    manager.connection.stopVPNTunnel()
}

// SystemExtension.swift - Installing extension
public static func install() async throws -> OSSystemExtensionRequest.Result? {
    try await Task.detached {
        try SystemExtension().activation()
    }.result.get()
}
```

### IPC Between App and Extension

1. **Config sharing**: App writes to `~/Library/Group Containers/group.Silent-Net.SilentX/`
2. **Status updates**: Via `NEVPNStatusDidChange` notifications
3. **Runtime commands**: Via `NETunnelProviderSession.sendProviderMessage()`

---

## Libbox Integration

### Option A: Build from Source

```bash
cd /path/to/sing-box
make build_local_for_apple
# Outputs: build/Libbox.xcframework
```

### Option B: Download Prebuilt

Check sing-box releases for `Libbox-apple-*.xcframework.zip`

### Key Libbox APIs (from ExtensionProvider.swift)

```swift
// Setup
LibboxSetup(options, &error)
LibboxRedirectStderr(logPath, &error)

// Service lifecycle
let commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &error)
commandServer.start()
commandServer.startOrReloadService(configContent, options: overrideOptions)
commandServer.closeService()
commandServer.close()
```

---

## Summary

| Question | Answer |
|----------|--------|
| How to avoid repeated passwords? | Use Network Extension - no passwords after system approval |
| What does SFM use? | System Extension + Libbox + NEPacketTunnelProvider |
| Keep LocalProcessEngine? | Yes, as dev/debug fallback |
| Implementation priority? | NetworkExtensionEngine is the primary goal now |
| App Store path? | Network Extension is required for App Store |

---

## Next Steps

1. Create `SilentX.System` target in Xcode
2. Configure entitlements and Info.plist
3. Integrate Libbox XCFramework
4. Implement `PacketTunnelProvider`
5. Implement `NetworkExtensionEngine` in main app
6. Add system extension installation UI
7. Test full connect/disconnect cycle without passwords

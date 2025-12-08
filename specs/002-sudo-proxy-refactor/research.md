# Research: Sudo Proxy Refactor

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-07
**Status**: Complete

## Research Questions

1. How to implement macOS privilege escalation for launching sing-box with root permissions?
2. How does sing-box for apple (SFM) implement TUN mode?
3. What architecture should we use: SMJobBless helper vs Network Extension?

---

## Decision 1: Privilege Escalation Approach

### Decision: Use Network Extension (NEPacketTunnelProvider) instead of sudo/SMJobBless

### Rationale

After researching sing-box for apple (SFM) implementation:

1. **SFM does NOT use sudo or SMJobBless** - It uses Apple's Network Extension framework
2. **NEPacketTunnelProvider** handles TUN interface creation natively without requiring root
3. **System Extension** (`SFM.System`) provides the packet tunnel functionality
4. **No password prompt needed** after initial system extension approval

### How SFM Works

```
SFM (Main App)
    ├── Uses NETunnelProviderManager to control tunnel
    ├── Calls manager.connection.startVPNTunnel()
    └── Passes username via options for path resolution

SFM.System (System Extension)
    ├── PacketTunnelProvider extends ExtensionProvider
    ├── ExtensionProvider extends NEPacketTunnelProvider
    ├── Creates LibboxNewService() with config content
    └── Calls service.start() to launch sing-box core
```

### Key Files in SFM

| File | Purpose |
|------|---------|
| `Library/Network/ExtensionProfile.swift` | Manages VPN tunnel start/stop |
| `Library/Network/ExtensionProvider.swift` | Base class for packet tunnel |
| `SystemExtension/PacketTunnelProvider.swift` | macOS system extension entry |
| `SFM/SFM.entitlements` | App capabilities |

### Alternatives Considered

| Approach | Pros | Cons |
|----------|------|------|
| **SMJobBless + Privileged Helper** | One-time password, then silent | Complex setup, needs helper daemon, launchd plist |
| **AuthorizationExecuteWithPrivileges** | Simple API | Deprecated since macOS 10.7, security risk |
| **Network Extension** | Apple-sanctioned, no password after approval, App Store compatible | Requires system extension approval, more complex architecture |
| **osascript do shell script with administrator privileges** | Quick hack | Not reliable, poor UX, not App Store compatible |

### Implementation Impact

- Need to create System Extension target in Xcode
- Need to embed sing-box core via Libbox (Go library compiled for Apple)
- Main app communicates with extension via NETunnelProviderManager
- No sudo prompt - uses macOS system extension approval flow

---

## Decision 2: Architecture for Hybrid Mode Support

### Decision: Protocol-based ProxyEngine abstraction with two implementations

### Rationale

The spec requires supporting both "Sudo Kernel Mode" and "Network Extension Mode" with easy switching. However, based on research:

1. **"Sudo Mode" is not how SFM works** - SFM uses Network Extension exclusively
2. **Direct process launch** (current approach) can work for HTTP proxy but NOT for TUN
3. **TUN requires root or Network Extension** - there's no middle ground

### Revised Architecture

```swift
protocol ProxyEngine {
    func start(config: ProxyConfiguration) async throws
    func stop() async throws
    var status: ConnectionStatus { get }
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { get }
}

// Implementation 1: Network Extension (recommended for TUN)
class NetworkExtensionEngine: ProxyEngine {
    // Uses NETunnelProviderManager
    // Requires System Extension target
    // Full TUN support
}

// Implementation 2: Local Process (for HTTP proxy only, no TUN)
class LocalProcessEngine: ProxyEngine {
    // Current approach - launches sing-box as subprocess
    // Works for mixed inbound (HTTP/SOCKS proxy)
    // Does NOT support TUN mode
    // No privilege escalation needed for non-privileged ports
}
```

### Mode Comparison

| Feature | LocalProcessEngine | NetworkExtensionEngine |
|---------|-------------------|----------------------|
| HTTP Proxy | Yes | Yes |
| SOCKS Proxy | Yes | Yes |
| TUN Mode | No (needs root) | Yes |
| Password Prompt | No | No (after approval) |
| App Store | Maybe | Yes |
| Complexity | Low | High |

### Alternatives Considered

Keeping "Sudo Mode" as originally specified:
- Would require SMJobBless privileged helper
- Adds significant complexity
- Not App Store compatible
- SFM doesn't do this, so it's not the industry standard

---

## Decision 3: Implementation Phasing

### Decision: Phase 1 - Fix LocalProcessEngine, Phase 2 - Add NetworkExtensionEngine

### Rationale

The current "Core process exited during startup" error needs to be fixed first. This is likely a configuration or permission issue, not an architectural problem.

### Phase 1: Fix Current Implementation (P1 Priority)
1. Debug why sing-box exits during startup
2. Improve error handling and logging
3. Ensure HTTP/SOCKS proxy mode works reliably
4. Refactor to ProxyEngine protocol for future extensibility

### Phase 2: Add Network Extension (P2 Priority)
1. Create System Extension target
2. Integrate Libbox (sing-box Go library)
3. Implement PacketTunnelProvider
4. Add TUN mode support

### Alternatives Considered

Implementing Network Extension first:
- More complex, longer time to fix current issues
- User can't use app at all until NE is complete
- Higher risk of integration issues

---

## Technical Details: Network Extension Implementation

### Required Entitlements (Main App)

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.your.app.identifier</string>
</array>
```

### Required Entitlements (System Extension)

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider-systemextension</string>
</array>
```

### Key APIs

```swift
// Starting tunnel (from main app)
let manager = NETunnelProviderManager()
try manager.connection.startVPNTunnel(options: [
    "username": NSString(string: NSUserName())
])

// In PacketTunnelProvider (system extension)
override func startTunnel(options: [String: NSObject]?) async throws {
    let service = LibboxNewService(configContent, platformInterface)
    try service.start()
}
```

### IPC Between App and Extension

- Use App Groups for shared UserDefaults and files
- Use `NETunnelProviderSession.sendProviderMessage()` for runtime commands
- Extension reads config from shared container path

---

## Research Sources

- [sing-box-for-apple GitHub Repository](https://github.com/SagerNet/sing-box-for-apple)
- Apple Developer Documentation: NetworkExtension Framework
- Apple Developer Documentation: System Extensions

---

## Summary

| Question | Answer |
|----------|--------|
| How to get root for TUN? | Use Network Extension, not sudo |
| What does SFM use? | NEPacketTunnelProvider in System Extension |
| Should we use SMJobBless? | No - Network Extension is the Apple-sanctioned approach |
| Implementation priority? | Fix LocalProcess first, add NE later |

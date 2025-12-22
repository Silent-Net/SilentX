# NetworkExtensionEngine Contract

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-12
**Version**: 1.0

## Overview

`NetworkExtensionEngine` is a `ProxyEngine` implementation that uses macOS Network Extension framework for passwordless proxy operation with full TUN support.

---

## Class Definition

```swift
/// Network Extension-based proxy engine
/// Uses NETunnelProviderManager to control a system extension that hosts sing-box
@MainActor
final class NetworkExtensionEngine: ProxyEngine {
    
    // MARK: - ProxyEngine Protocol
    
    var status: ConnectionStatus { statusSubject.value }
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { statusSubject.eraseToAnyPublisher() }
    let engineType: EngineType = .networkExtension
    
    // MARK: - Private Properties
    
    private var statusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private var profile: ExtensionProfile?
    private var statusObserver: Any?
    
    // MARK: - Lifecycle
    
    func start(config: ProxyConfiguration) async throws {
        // Implementation below
    }
    
    func stop() async throws {
        // Implementation below
    }
    
    func validate(config: ProxyConfiguration) async -> [ProxyError] {
        // Implementation below
    }
}
```

---

## Method Contracts

### `start(config:)`

**Purpose**: Start VPN tunnel via Network Extension.

**Preconditions**:
- `status == .disconnected`
- System extension must be installed
- Config file must exist and be valid

**Postconditions**:
- On success: `status == .connected`
- On failure: `status == .error(reason)`
- Config written to App Group shared container
- VPN profile installed/updated in System Preferences
- Status observer registered

**Sequence**:
```
1. Guard status == .disconnected
2. statusSubject.send(.connecting)
3. Check SystemExtension.isInstalled()
   → If false: throw .extensionNotInstalled
4. profile = ExtensionProfile.load()
   → If nil: ExtensionProfile.install(), then load again
5. Write config to sharedConfigPath
6. profile.register() - observe NEVPNStatus
7. observeStatusChanges() - map NEVPNStatus to ConnectionStatus
8. try profile.start()
   → On error: throw .tunnelStartFailed(detail)
9. Wait for NEVPNStatus == .connected (timeout 30s)
   → On timeout: throw .timeout
10. statusSubject.send(.connected(info))
```

**Error Mapping**:
| Condition | ProxyError |
|-----------|------------|
| Extension not installed | `.extensionNotInstalled` |
| VPN profile load fails | `.extensionLoadFailed(detail)` |
| Tunnel start fails | `.tunnelStartFailed(detail)` |
| Config write fails | `.configInvalid(detail)` |
| Timeout waiting for connected | `.timeout` |

---

### `stop()`

**Purpose**: Stop VPN tunnel and cleanup.

**Preconditions**:
- `status == .connected` OR `status == .error`

**Postconditions**:
- `status == .disconnected`
- VPN tunnel stopped
- Status observer removed

**Sequence**:
```
1. Guard status is .connected or .error
2. statusSubject.send(.disconnecting)
3. Remove status observer
4. try profile.stop()
   → On error: log but continue cleanup
5. profile = nil
6. statusSubject.send(.disconnected)
```

---

### `validate(config:)`

**Purpose**: Pre-flight validation before starting.

**Returns**: Array of `ProxyError`, empty if valid.

**Checks**:
```swift
var errors: [ProxyError] = []

// 1. Check system extension installed
if !await SystemExtension.isInstalled() {
    errors.append(.extensionNotInstalled)
}

// 2. Check config file exists
if !FileManager.default.fileExists(atPath: config.configPath.path) {
    errors.append(.configNotFound)
}

// 3. Validate config JSON format
do {
    let content = try String(contentsOf: config.configPath)
    let validation = configurationService.validate(json: content)
    if !validation.isValid {
        errors.append(.configInvalid(validation.errors.first?.message ?? "Invalid"))
    }
} catch {
    errors.append(.configInvalid("Cannot read config: \(error)"))
}

return errors
```

---

## Status Observation

### NEVPNStatus → ConnectionStatus Mapping

```swift
private func observeStatusChanges() {
    statusObserver = NotificationCenter.default.addObserver(
        forName: .NEVPNStatusDidChange,
        object: profile?.manager.connection,
        queue: .main
    ) { [weak self] _ in
        guard let self, let profile = self.profile else { return }
        
        let newStatus: ConnectionStatus
        switch profile.status {
        case .invalid, .disconnected:
            newStatus = .disconnected
        case .connecting, .reasserting:
            newStatus = .connecting
        case .connected:
            newStatus = .connected(ConnectionInfo(
                engineType: .networkExtension,
                startTime: profile.connectedDate ?? Date(),
                configName: "Active Profile",
                listenPorts: []  // TUN mode doesn't expose ports
            ))
        case .disconnecting:
            newStatus = .disconnecting
        @unknown default:
            newStatus = .disconnected
        }
        
        self.statusSubject.send(newStatus)
    }
}
```

---

## Integration Points

### With ConnectionService

```swift
// ConnectionService creates NetworkExtensionEngine when profile.preferredEngine == .networkExtension
func connect(profile: Profile) async throws {
    let engine: ProxyEngine
    switch profile.preferredEngine {
    case .networkExtension:
        engine = NetworkExtensionEngine()
    case .localProcess:
        engine = LocalProcessEngine()
    }
    // ... rest of connection logic
}
```

### With SystemExtension

```swift
// Check if extension needs installation
if !await SystemExtension.isInstalled() {
    // Show UI prompting user to install
    // User clicks "Install System Extension"
    try await SystemExtension.install()
}
```

### With ExtensionProfile

```swift
// ExtensionProfile wraps NETunnelProviderManager
let profile = try await ExtensionProfile.load()
try await profile.start()  // Triggers startVPNTunnel
try await profile.stop()   // Triggers stopVPNTunnel
```

---

## Error Handling

### User-Facing Error Messages

| Error | Chinese Message | Recovery Action |
|-------|-----------------|-----------------|
| `.extensionNotInstalled` | "系统扩展未安装，请先安装" | Show install button |
| `.extensionNotApproved` | "请在系统偏好设置中允许系统扩展" | Open System Preferences |
| `.extensionLoadFailed` | "加载 VPN 配置失败" | Retry or reinstall |
| `.tunnelStartFailed` | "启动隧道失败: {detail}" | Check config, retry |

### Error Recovery Flow

```
User clicks Connect
        │
        ▼
Check extension installed?
        │
    No ──┴── Yes
    │         │
    ▼         ▼
Show "Install Extension"  → Start tunnel
        │
        ▼
User clicks Install
        │
        ▼
SystemExtension.install()
        │
    Success ──┴── Needs Approval
        │              │
        │              ▼
        │    Show "Open System Preferences"
        │              │
        │              ▼
        │    User approves in System Prefs
        │              │
        └──────────────┤
                       │
                       ▼
              Retry connection
```

---

## Testing Contract

### Unit Tests

```swift
class NetworkExtensionEngineTests: XCTestCase {
    
    func testStartWithoutExtension() async throws {
        // Given: Extension not installed
        // When: start() called
        // Then: throws .extensionNotInstalled
    }
    
    func testStartSuccess() async throws {
        // Given: Extension installed, valid config
        // When: start() called
        // Then: status becomes .connected
    }
    
    func testStopSuccess() async throws {
        // Given: Engine is connected
        // When: stop() called
        // Then: status becomes .disconnected
    }
    
    func testStatusObservation() async throws {
        // Given: Engine started
        // When: NEVPNStatus changes
        // Then: statusPublisher emits corresponding ConnectionStatus
    }
}
```

### Integration Tests

```swift
class NetworkExtensionIntegrationTests: XCTestCase {
    
    func testFullConnectDisconnectCycle() async throws {
        // Requires: System extension actually installed
        // Tests: Full user flow without password prompts
    }
    
    func testReconnectAfterAppRestart() async throws {
        // Requires: System extension running
        // Tests: App can observe existing tunnel state
    }
}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-12 | Initial contract definition |

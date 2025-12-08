# Quickstart: Sudo Proxy Refactor Implementation

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-07

## Overview

This guide provides step-by-step implementation instructions for refactoring SilentX's proxy architecture.

---

## Phase 1: Fix Current Implementation (Priority P1)

### Goal
Make LocalProcessEngine reliable for HTTP/SOCKS proxy mode.

### Step 1.1: Create ProxyEngine Protocol

**File**: `SilentX/Services/Engines/ProxyEngine.swift`

```swift
import Combine
import Foundation

enum EngineType: String, Codable {
    case localProcess
    case networkExtension
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected(ConnectionInfo)
    case disconnecting
    case error(ProxyError)
}

struct ConnectionInfo: Equatable {
    let engineType: EngineType
    let startTime: Date
    let configName: String
    let listenPorts: [Int]

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

@MainActor
protocol ProxyEngine: AnyObject {
    var status: ConnectionStatus { get }
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { get }
    var engineType: EngineType { get }

    func start(config: ProxyConfiguration) async throws
    func stop() async throws
    func validate(config: ProxyConfiguration) async -> [ProxyError]
}
```

### Step 1.2: Create ProxyError Enum

**File**: `SilentX/Services/Engines/ProxyError.swift`

```swift
enum ProxyError: Error, Equatable, LocalizedError {
    case configInvalid(String)
    case configNotFound
    case coreNotFound
    case coreStartFailed(String)
    case portConflict([Int])
    case permissionDenied
    case extensionNotApproved
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .configInvalid(let detail): return "配置文件错误: \(detail)"
        case .configNotFound: return "未找到配置文件"
        case .coreNotFound: return "未找到 sing-box 核心"
        case .coreStartFailed(let detail): return "核心启动失败: \(detail)"
        case .portConflict(let ports): return "端口被占用: \(ports.map(String.init).joined(separator: ", "))"
        case .permissionDenied: return "权限不足"
        case .extensionNotApproved: return "请在系统设置中允许系统扩展"
        case .timeout: return "操作超时"
        case .unknown(let detail): return "未知错误: \(detail)"
        }
    }
}
```

### Step 1.3: Implement LocalProcessEngine

**File**: `SilentX/Services/Engines/LocalProcessEngine.swift`

Key improvements over current ConnectionService:

1. **Better process monitoring**: Check process.isRunning more frequently
2. **Improved error capture**: Parse stderr for specific error messages
3. **Port validation before start**: Fail fast if ports are in use
4. **Graceful shutdown**: SIGTERM → wait → SIGKILL if needed

```swift
@MainActor
final class LocalProcessEngine: ProxyEngine {
    // Implementation details in contracts/proxy-engine.md
}
```

### Step 1.4: Refactor ConnectionService

Modify `ConnectionService.swift` to use `ProxyEngine` protocol:

```swift
@MainActor
class ConnectionService: ObservableObject {
    @Published private(set) var status: ConnectionStatus = .disconnected
    private var engine: ProxyEngine?

    func connect(profile: Profile, engineType: EngineType = .localProcess) async throws {
        // Create appropriate engine
        engine = engineType == .localProcess
            ? LocalProcessEngine()
            : nil // NetworkExtensionEngine added in Phase 2

        guard let engine else {
            throw ProxyError.unknown("Engine not available")
        }

        // Subscribe to status changes
        engine.statusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$status)

        // Build config and start
        let config = try buildConfiguration(from: profile)
        try await engine.start(config: config)
    }

    func disconnect() async throws {
        try await engine?.stop()
        engine = nil
    }
}
```

### Step 1.5: Debug Current Startup Issue

The "Core process exited during startup" error. Debug checklist:

1. **Check sing-box binary**:
   ```bash
   file /path/to/sing-box  # Should show Mach-O executable
   xattr -l /path/to/sing-box  # Remove quarantine if present
   ```

2. **Test config manually**:
   ```bash
   /path/to/sing-box check -c /path/to/config.json
   /path/to/sing-box run -c /path/to/config.json
   ```

3. **Add detailed logging in engine**:
   - Log exact command being run
   - Log stderr output on failure
   - Log exit code

4. **Common issues**:
   - TUN mode in config requires root → remove TUN inbound for now
   - Invalid outbound credentials
   - DNS configuration errors

---

## Phase 2: Add Network Extension (Priority P2)

### Goal
Enable TUN mode via System Extension.

### Step 2.1: Create System Extension Target

1. In Xcode: File → New → Target → System Extension
2. Name: `SilentX.System`
3. Type: Network Extension

### Step 2.2: Configure Entitlements

**SilentX/SilentX.entitlements** (Main App):
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.your.bundle.id</string>
</array>
```

**SilentX.System/SilentX.System.entitlements**:
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider-systemextension</string>
</array>
```

### Step 2.3: Implement PacketTunnelProvider

**File**: `SilentX.System/PacketTunnelProvider.swift`

```swift
import NetworkExtension
import Libbox  // sing-box Go library

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var service: LibboxBoxService?

    override func startTunnel(options: [String: NSObject]?) async throws {
        // Read config from shared container
        let configPath = sharedContainerURL.appendingPathComponent("active-config.json")
        let configContent = try String(contentsOf: configPath)

        // Start sing-box
        service = LibboxNewService(configContent, self)
        try service?.start()
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        try? service?.close()
        service = nil
    }
}
```

### Step 2.4: Implement NetworkExtensionEngine

**File**: `SilentX/Services/Engines/NetworkExtensionEngine.swift`

```swift
@MainActor
final class NetworkExtensionEngine: ProxyEngine {
    private var manager: NETunnelProviderManager?

    func start(config: ProxyConfiguration) async throws {
        // Write config to shared container for extension to read
        try writeConfigToSharedContainer(config)

        // Load or create manager
        manager = try await loadOrCreateManager()

        // Start tunnel
        try manager?.connection.startVPNTunnel()
    }

    func stop() async throws {
        manager?.connection.stopVPNTunnel()
    }
}
```

---

## Testing Strategy

### Unit Tests

```swift
// Test LocalProcessEngine
class LocalProcessEngineTests: XCTestCase {
    func testStartWithValidConfig() async throws
    func testStartWithInvalidConfigThrows() async throws
    func testStopWhileConnected() async throws
    func testProcessCrashUpdatesStatus() async throws
}

// Test ProxyEngine protocol conformance
class ProxyEngineContractTests: XCTestCase {
    func testAllEnginesConformToProtocol()
}
```

### Integration Tests

```swift
// Test actual sing-box launch (requires binary)
class SingBoxIntegrationTests: XCTestCase {
    func testLaunchWithHTTPProxy() async throws
    func testLaunchWithSOCKSProxy() async throws
    func testGracefulShutdown() async throws
}
```

---

## File Checklist

### Phase 1 Files

- [ ] `SilentX/Services/Engines/ProxyEngine.swift` - Protocol
- [ ] `SilentX/Services/Engines/ProxyError.swift` - Error types
- [ ] `SilentX/Services/Engines/ProxyConfiguration.swift` - Config model
- [ ] `SilentX/Services/Engines/LocalProcessEngine.swift` - Implementation
- [ ] `SilentX/Services/ConnectionService.swift` - Refactored
- [ ] `SilentXTests/EngineTests/LocalProcessEngineTests.swift` - Tests
- [ ] `SilentXTests/EngineTests/MockProxyEngine.swift` - Mock for UI tests

### Phase 2 Files

- [ ] `SilentX.System/` - System Extension target
- [ ] `SilentX.System/PacketTunnelProvider.swift` - Tunnel provider
- [ ] `SilentX/Services/Engines/NetworkExtensionEngine.swift` - NE implementation
- [ ] Updated entitlements for both targets
- [ ] Libbox framework integration

---

## Success Verification

### Phase 1 Complete When

1. [ ] User can click Connect and proxy starts (HTTP/SOCKS mode)
2. [ ] Process crash is detected and UI updates within 2 seconds
3. [ ] Clear error messages shown for common failure cases
4. [ ] Tests pass for LocalProcessEngine

### Phase 2 Complete When

1. [ ] System Extension installs and gets user approval
2. [ ] TUN mode works (all traffic routed through proxy)
3. [ ] No password prompt after initial approval
4. [ ] Tests pass for NetworkExtensionEngine

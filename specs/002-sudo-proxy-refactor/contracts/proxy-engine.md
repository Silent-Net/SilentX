# ProxyEngine Protocol Contract

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-07
**Version**: 1.0

## Overview

`ProxyEngine` defines the contract for proxy implementations. All engines must conform to this protocol to ensure consistent behavior across different proxy strategies.

---

## Protocol Definition

```swift
/// Protocol defining the contract for proxy engine implementations.
/// Engines handle starting, stopping, and monitoring proxy connections.
@MainActor
protocol ProxyEngine: AnyObject {

    // MARK: - Properties

    /// Current connection status
    var status: ConnectionStatus { get }

    /// Publisher for status changes (for Combine subscribers)
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { get }

    /// Type identifier for this engine
    var engineType: EngineType { get }

    // MARK: - Lifecycle Methods

    /// Start the proxy with the given configuration.
    /// - Parameter config: Configuration containing paths and settings
    /// - Throws: ProxyError if startup fails
    /// - Precondition: status must be .disconnected
    func start(config: ProxyConfiguration) async throws

    /// Stop the proxy and cleanup resources.
    /// - Throws: ProxyError if shutdown fails
    /// - Precondition: status must be .connected or .error
    func stop() async throws

    // MARK: - Optional Methods

    /// Validate configuration before starting.
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validate(config: ProxyConfiguration) async -> [ProxyError]
}
```

---

## Status Transitions

### Valid Transitions

| From | To | Trigger |
|------|----|---------|
| `.disconnected` | `.connecting` | `start()` called |
| `.connecting` | `.connected` | Engine successfully started |
| `.connecting` | `.error` | Startup failed |
| `.connected` | `.disconnecting` | `stop()` called |
| `.connected` | `.error` | Runtime error detected |
| `.disconnecting` | `.disconnected` | Cleanup complete |
| `.error` | `.disconnected` | Error acknowledged/reset |
| `.error` | `.connecting` | Retry via `start()` |

### Invalid Transitions (Must Throw)

- `start()` when status is `.connecting`, `.connected`, or `.disconnecting`
- `stop()` when status is `.disconnected` or `.connecting`

---

## Error Handling Contract

### Startup Errors

| Scenario | Error | Recovery |
|----------|-------|----------|
| Config file not found | `.configNotFound` | User selects profile |
| Config JSON invalid | `.configInvalid(detail)` | User fixes config |
| Core binary missing | `.coreNotFound` | Download core version |
| Port already in use | `.portConflict(ports)` | User closes conflicting app |
| Startup timeout (>30s) | `.timeout` | User retries |
| Process exits immediately | `.coreStartFailed(detail)` | Check logs, fix config |
| Extension not approved | `.extensionNotApproved` | User approves in System Settings |

### Runtime Errors

| Scenario | Error | Auto-Recovery |
|----------|-------|---------------|
| Process crashes | `.coreStartFailed(detail)` | No - notify user |
| Network lost | (handled by core) | Yes - core reconnects |

---

## Implementation Requirements

### LocalProcessEngine

1. **Must** launch sing-box via `Process` API
2. **Must** monitor process termination
3. **Must** capture stdout/stderr for logging
4. **Must** cleanup zombie processes on stop
5. **Must** support HTTP/SOCKS inbound only (no TUN)
6. **Must** verify ports are available before starting

### NetworkExtensionEngine

1. **Must** use `NETunnelProviderManager` for tunnel control
2. **Must** handle extension approval flow
3. **Must** support TUN mode via System Extension
4. **Must** communicate config via App Groups
5. **Must** handle extension not installed gracefully

---

## Testing Contract

### Unit Test Requirements

Each engine implementation must pass:

```swift
// Test: Start from disconnected succeeds
func testStartFromDisconnected() async throws

// Test: Start when already connected throws
func testStartWhenConnectedThrows() async throws

// Test: Stop from connected succeeds
func testStopFromConnected() async throws

// Test: Stop when disconnected throws
func testStopWhenDisconnectedThrows() async throws

// Test: Invalid config throws appropriate error
func testInvalidConfigThrows() async throws

// Test: Status publisher emits on changes
func testStatusPublisherEmitsChanges() async throws
```

### Mock Engine

A `MockProxyEngine` must be provided for UI testing:

```swift
class MockProxyEngine: ProxyEngine {
    var mockStatus: ConnectionStatus = .disconnected
    var shouldFailStart = false
    var startDelay: TimeInterval = 0
    // ... implementation
}
```

---

## Usage Example

```swift
// In ConnectionService
class ConnectionService: ObservableObject {
    private var engine: ProxyEngine

    init(engineType: EngineType) {
        self.engine = engineType == .localProcess
            ? LocalProcessEngine()
            : NetworkExtensionEngine()
    }

    func connect(profile: Profile) async throws {
        let config = ProxyConfiguration(from: profile)

        // Validate first
        let errors = await engine.validate(config: config)
        guard errors.isEmpty else {
            throw errors.first!
        }

        // Start engine
        try await engine.start(config: config)
    }

    func disconnect() async throws {
        try await engine.stop()
    }
}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-07 | Initial protocol definition |

# Data Model: Sudo Proxy Refactor

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-07

## Entity Overview

```
┌─────────────────────┐     ┌─────────────────────┐
│   ProxyEngine       │────▶│  ConnectionStatus   │
│   (Protocol)        │     │  (Value Type)       │
└─────────────────────┘     └─────────────────────┘
         ▲
         │ implements
    ┌────┴────┐
    │         │
┌───┴───┐ ┌───┴───┐
│Local  │ │Network│
│Process│ │Ext.   │
│Engine │ │Engine │
└───────┘ └───────┘
```

---

## Core Entities

### 1. ProxyEngine (Protocol)

**Purpose**: Abstract interface for different proxy implementation strategies.

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `status` | `ConnectionStatus` | Current connection state |
| `statusPublisher` | `AnyPublisher<ConnectionStatus, Never>` | Reactive status updates |
| `start(config:)` | `async throws` | Start proxy with given configuration |
| `stop()` | `async throws` | Stop proxy and cleanup |
| `engineType` | `EngineType` | Identifies which engine implementation |

**Validation Rules**:
- Cannot call `start()` if status is `.connected` or `.connecting`
- Cannot call `stop()` if status is `.disconnected`
- Must transition through proper states (disconnected → connecting → connected)

---

### 2. ConnectionStatus (Enum)

**Purpose**: Represents the current state of the proxy connection.

| Case | Associated Values | Description |
|------|-------------------|-------------|
| `.disconnected` | None | No active connection |
| `.connecting` | None | Connection in progress |
| `.connected` | `ConnectionInfo` | Active connection with details |
| `.disconnecting` | None | Disconnection in progress |
| `.error` | `ProxyError` | Connection failed with error |

**State Transitions**:
```
disconnected ──start()──▶ connecting ──success──▶ connected
     ▲                        │                      │
     │                        ▼ failure              ▼ stop()
     └──────────────────── error ◀───────────── disconnecting
```

---

### 3. ConnectionInfo (Struct)

**Purpose**: Details about an active connection.

| Field | Type | Description |
|-------|------|-------------|
| `engineType` | `EngineType` | Which engine is running |
| `startTime` | `Date` | When connection started |
| `configName` | `String` | Name of active profile |
| `listenPorts` | `[Int]` | Ports being listened on |

**Computed Properties**:
- `duration: TimeInterval` - How long connected
- `formattedDuration: String` - Human-readable duration

---

### 4. ProxyError (Enum)

**Purpose**: Categorized errors for better user messaging.

| Case | Description | User Message |
|------|-------------|--------------|
| `.configInvalid(String)` | Config file parse error | "配置文件错误: {detail}" |
| `.configNotFound` | Config file missing | "未找到配置文件" |
| `.coreNotFound` | sing-box binary missing | "未找到 sing-box 核心" |
| `.coreStartFailed(String)` | Core exited unexpectedly | "核心启动失败: {detail}" |
| `.portConflict([Int])` | Ports already in use | "端口被占用: {ports}" |
| `.permissionDenied` | Missing required permissions | "权限不足" |
| `.extensionNotApproved` | System extension not approved | "请在系统设置中允许系统扩展" |
| `.timeout` | Operation timed out | "操作超时" |
| `.unknown(String)` | Unexpected error | "未知错误: {detail}" |

---

### 5. EngineType (Enum)

**Purpose**: Identifies which proxy engine implementation is in use.

| Case | Description |
|------|-------------|
| `.localProcess` | Direct sing-box process launch (HTTP/SOCKS only) |
| `.networkExtension` | System extension with TUN support |

---

### 6. ProxyConfiguration (Struct)

**Purpose**: Configuration passed to engine for startup.

| Field | Type | Description |
|-------|------|-------------|
| `profileId` | `UUID` | Reference to Profile model |
| `configPath` | `URL` | Path to sing-box JSON config |
| `corePath` | `URL` | Path to sing-box binary |
| `logLevel` | `LogLevel` | Logging verbosity |

**Validation Rules**:
- `configPath` must exist and be readable
- `corePath` must exist and be executable
- Config JSON must be valid sing-box format

---

## Existing Entities (Modified)

### Profile (Existing SwiftData Model)

**Changes**:
- Add `preferredEngine: EngineType` field for user preference
- Default value: `.localProcess`

### ConnectionStatistics (Existing)

**No changes** - continues to track upload/download bytes and speeds.

---

## Entity Relationships

```
Profile
    │
    │ 1:1 (selected)
    ▼
ProxyConfiguration ──────▶ ProxyEngine.start()
                                │
                                ▼
                         ConnectionStatus
                                │
                                ├── .connected(ConnectionInfo)
                                │        │
                                │        └── includes EngineType
                                │
                                └── .error(ProxyError)
```

---

## Storage Strategy

| Entity | Storage | Reason |
|--------|---------|--------|
| ProxyEngine | In-memory only | Runtime service, no persistence |
| ConnectionStatus | In-memory only | Transient state |
| ConnectionInfo | In-memory only | Derived from runtime |
| ProxyError | In-memory only | Transient |
| ProxyConfiguration | Derived from Profile | Profile is SwiftData persisted |
| EngineType preference | SwiftData (in Profile) | User setting persisted |

---

## Concurrency Considerations

- All engine operations are `async`
- Status updates published on `MainActor`
- Engine implementations must be thread-safe
- Use `@MainActor` for UI-bound status updates

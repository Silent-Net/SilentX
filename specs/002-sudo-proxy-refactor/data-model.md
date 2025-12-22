# Data Model: Dual-Core Proxy Architecture (双内核模式)

**Feature**: 002-sudo-proxy-refactor
**Date**: 2025-12-12 (Updated)

## Entity Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Main App Domain                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐     ┌─────────────────────┐                   │
│  │   ProxyEngine       │────▶│  ConnectionStatus   │                   │
│  │   (Protocol)        │     │  (Value Type)       │                   │
│  └─────────────────────┘     └─────────────────────┘                   │
│           ▲                                                             │
│           │ implements                                                  │
│      ┌────┴────────────────┐                                           │
│      │                     │                                            │
│  ┌───┴───────────┐    ┌────┴────────────────┐                          │
│  │LocalProcess   │    │NetworkExtension     │                          │
│  │Engine         │    │Engine               │                          │
│  │(sudo mode)    │    │(TUN mode)           │                          │
│  └───────────────┘    └─────────────────────┘                          │
│                              │                                          │
│                              │ uses                                     │
│                              ▼                                          │
│  ┌───────────────────────────────────────────┐                         │
│  │ ExtensionProfile                          │                         │
│  │ (NETunnelProviderManager wrapper)         │                         │
│  └───────────────────────────────────────────┘                         │
│                              │                                          │
│                              │ manages                                  │
│                              ▼                                          │
│  ┌───────────────────────────────────────────┐                         │
│  │ SystemExtension                           │                         │
│  │ (OSSystemExtensionRequest wrapper)        │                         │
│  └───────────────────────────────────────────┘                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ IPC via NetworkExtension framework
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      System Extension Domain                            │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────┐                         │
│  │ PacketTunnelProvider                      │                         │
│  │ (NEPacketTunnelProvider subclass)         │                         │
│  └───────────────────────────────────────────┘                         │
│                              │                                          │
│                              │ uses                                     │
│                              ▼                                          │
│  ┌───────────────────────────────────────────┐                         │
│  │ ExtensionPlatformInterface                │                         │
│  │ (Libbox callback handler)                 │                         │
│  └───────────────────────────────────────────┘                         │
│                              │                                          │
│                              │ interacts with                           │
│                              ▼                                          │
│  ┌───────────────────────────────────────────┐                         │
│  │ Libbox (LibboxCommandServer)              │                         │
│  │ (sing-box Go library)                     │                         │
│  └───────────────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Entities (Existing - Enhanced)

### 1. ProxyEngine (Protocol) - Existing

**Purpose**: Abstract interface for different proxy implementation strategies.

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `status` | `ConnectionStatus` | Current connection state |
| `statusPublisher` | `AnyPublisher<ConnectionStatus, Never>` | Reactive status updates |
| `engineType` | `EngineType` | Identifies which engine implementation |
| `start(config:)` | `async throws` | Start proxy with given configuration |
| `stop()` | `async throws` | Stop proxy and cleanup |
| `validate(config:)` | `async -> [ProxyError]` | Pre-start validation |

**Validation Rules**:
- Cannot call `start()` if status is `.connected` or `.connecting`
- Cannot call `stop()` if status is `.disconnected`
- Must transition through proper states (disconnected → connecting → connected)

---

### 2. ConnectionStatus (Enum) - Existing

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

### 3. EngineType (Enum) - Existing

**Purpose**: Identifies which proxy engine implementation is in use.

| Case | Description |
|------|-------------|
| `.localProcess` | Direct sing-box process launch via sudo (HTTP/SOCKS, dev mode) |
| `.networkExtension` | System extension with TUN support (production mode) |

**Display Names (Chinese)**:
- `.localProcess` → "本地进程模式"
- `.networkExtension` → "系统扩展模式"

---

### 4. ProxyError (Enum) - Enhanced

**Purpose**: Categorized errors for better user messaging.

| Case | Description | User Message |
|------|-------------|--------------|
| `.configInvalid(String)` | Config file parse error | "配置文件错误: {detail}" |
| `.configNotFound` | Config file missing | "未找到配置文件" |
| `.coreNotFound` | sing-box binary missing | "未找到 sing-box 核心" |
| `.coreStartFailed(String)` | Core exited unexpectedly | "核心启动失败: {detail}" |
| `.portConflict([Int])` | Ports already in use | "端口被占用: {ports}" |
| `.permissionDenied` | Missing required permissions | "权限不足" |
| `.extensionNotInstalled` | 🆕 System extension not installed | "请先安装系统扩展" |
| `.extensionNotApproved` | 🆕 System extension pending approval | "请在系统设置中允许系统扩展" |
| `.extensionLoadFailed(String)` | 🆕 VPN profile load failed | "加载 VPN 配置失败: {detail}" |
| `.tunnelStartFailed(String)` | 🆕 Tunnel start failed | "隧道启动失败: {detail}" |
| `.timeout` | Operation timed out | "操作超时" |
| `.unknown(String)` | Unexpected error | "未知错误: {detail}" |

---

## New Entities (Network Extension)

### 5. ExtensionProfile (Class) 🆕

**Purpose**: Wrapper around `NETunnelProviderManager` for managing VPN tunnel lifecycle.

**Location**: `SilentX/Services/Engines/ExtensionProfile.swift`

| Property | Type | Description |
|----------|------|-------------|
| `manager` | `NEVPNManager` (private) | Underlying VPN manager |
| `connection` | `NEVPNConnection` (private) | VPN connection handle |
| `status` | `NEVPNStatus` (published) | Current tunnel status |
| `connectedDate` | `Date?` (published) | When tunnel connected |

| Method | Signature | Description |
|--------|-----------|-------------|
| `register()` | `func register()` | Start observing status changes |
| `start()` | `async throws` | Start VPN tunnel |
| `stop()` | `async throws` | Stop VPN tunnel |
| `restart()` | `async throws` | Stop then start |
| `updateAlwaysOn(_:)` | `async throws` | Toggle on-demand |

**Static Methods**:
| Method | Signature | Description |
|--------|-----------|-------------|
| `load()` | `static async throws -> ExtensionProfile?` | Load existing profile |
| `install()` | `static async throws` | Install new profile |

**NEVPNStatus Mapping**:
```swift
NEVPNStatus → ConnectionStatus
.invalid        → .disconnected
.disconnected   → .disconnected
.connecting     → .connecting
.connected      → .connected(info)
.reasserting    → .connecting
.disconnecting  → .disconnecting
```

---

### 6. SystemExtension (Class) 🆕

**Purpose**: Wrapper around `OSSystemExtensionRequest` for managing system extension lifecycle.

**Location**: `SilentX/Services/Engines/SystemExtension.swift`

| Property | Type | Description |
|----------|------|-------------|
| `forceUpdate` | `Bool` (private) | Force replace existing extension |
| `inBackground` | `Bool` (private) | Silent update mode |
| `result` | `OSSystemExtensionRequest.Result?` | Installation result |
| `properties` | `[OSSystemExtensionProperties]?` | Extension info |
| `error` | `Error?` | Any error during request |

| Method | Signature | Description |
|--------|-----------|-------------|
| `activation()` | `throws -> Result?` | Submit activation request |
| `deactivation()` | `throws -> Result?` | Submit deactivation request |
| `getProperties()` | `throws -> [Properties]` | Query extension status |

**Static Methods**:
| Method | Signature | Description |
|--------|-----------|-------------|
| `isInstalled()` | `static async -> Bool` | Check if extension is installed |
| `install(forceUpdate:inBackground:)` | `static async throws -> Result?` | Install/update extension |
| `uninstall()` | `static async throws -> Result?` | Uninstall extension |

**OSSystemExtensionRequestDelegate**:
- `request(_:actionForReplacingExtension:withExtension:)` → Handle version updates
- `requestNeedsUserApproval(_:)` → User must approve in System Preferences
- `request(_:didFinishWithResult:)` → Installation complete
- `request(_:didFailWithError:)` → Installation failed
- `request(_:foundProperties:)` → Properties query result

---

### 7. NetworkExtensionEngine (Class) 🆕

**Purpose**: `ProxyEngine` implementation using Network Extension framework.

**Location**: `SilentX/Services/Engines/NetworkExtensionEngine.swift`

| Property | Type | Description |
|----------|------|-------------|
| `profile` | `ExtensionProfile?` | VPN profile wrapper |
| `statusSubject` | `CurrentValueSubject<ConnectionStatus, Never>` | Status publisher |
| `observer` | `Any?` | Notification observer for status |

| Method | Signature | Description |
|--------|-----------|-------------|
| `start(config:)` | `async throws` | Write config to App Group, start tunnel |
| `stop()` | `async throws` | Stop tunnel, cleanup observer |
| `validate(config:)` | `async -> [ProxyError]` | Check extension installed, config valid |

**Start Flow**:
```swift
func start(config: ProxyConfiguration) async throws {
    // 1. Check system extension installed
    guard await SystemExtension.isInstalled() else {
        throw ProxyError.extensionNotInstalled
    }
    
    // 2. Load or create ExtensionProfile
    profile = try await ExtensionProfile.load()
    if profile == nil {
        try await ExtensionProfile.install()
        profile = try await ExtensionProfile.load()
    }
    
    // 3. Write config to App Group shared container
    let sharedConfig = FilePath.sharedConfigPath
    try config.content.write(to: sharedConfig, atomically: true, encoding: .utf8)
    
    // 4. Register for status updates
    profile?.register()
    observeStatusChanges()
    
    // 5. Start tunnel
    try await profile?.start()
}
```

---

### 8. PacketTunnelProvider (Class) 🆕

**Purpose**: `NEPacketTunnelProvider` subclass in system extension that hosts Libbox.

**Location**: `SilentX.System/PacketTunnelProvider.swift`

| Property | Type | Description |
|----------|------|-------------|
| `username` | `String?` | macOS username for path resolution |
| `commandServer` | `LibboxCommandServer!` | Libbox service manager |
| `platformInterface` | `ExtensionPlatformInterface!` | Libbox callbacks |

| Method | Signature | Description |
|--------|-----------|-------------|
| `startTunnel(options:)` | `async throws` | Initialize Libbox, start service |
| `stopTunnel(with:)` | `async` | Stop service, cleanup |
| `sleep()` | `async` | Pause on system sleep |
| `wake()` | `()` | Resume on system wake |

**startTunnel Implementation**:
```swift
override func startTunnel(options: [String: NSObject]?) async throws {
    // 1. Extract username from options (for path resolution)
    guard let usernameObj = options?["username"] as? NSString else {
        throw ExtensionError("missing username option")
    }
    username = String(usernameObj)
    
    // 2. Setup Libbox paths
    let setupOptions = LibboxSetupOptions()
    setupOptions.basePath = sharedContainerPath
    setupOptions.workingPath = workingDirectory
    setupOptions.tempPath = cacheDirectory
    LibboxSetup(setupOptions, &error)
    
    // 3. Create command server
    platformInterface = ExtensionPlatformInterface(self)
    commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &error)
    try commandServer.start()
    
    // 4. Read config from App Group
    let configContent = try String(contentsOf: sharedConfigPath, encoding: .utf8)
    
    // 5. Start sing-box service
    try commandServer.startOrReloadService(configContent, options: LibboxOverrideOptions())
}
```

---

### 9. ExtensionPlatformInterface (Class) 🆕

**Purpose**: Implements Libbox callback protocols for TUN packet handling.

**Location**: `SilentX.System/ExtensionPlatformInterface.swift`

| Protocol | Description |
|----------|-------------|
| `LibboxPlatformInterface` | Platform-specific callbacks |
| `LibboxCommandServerHandler` | Command server event handler |

**Key Methods**:
| Method | Description |
|--------|-------------|
| `openTun(options:)` | Create TUN interface via NEPacketTunnelNetworkSettings |
| `writePlatformMessage(_:message:)` | Handle log messages |
| `writeGroups(_:)` | Handle proxy group updates |
| `writeNetwork(_:)` | Handle network state changes |

---

## Shared Storage (App Group)

### FilePath Extensions 🆕

**Purpose**: Paths for App Group shared container.

**Location**: `SilentX/Shared/FilePath.swift`

| Property | Path | Description |
|----------|------|-------------|
| `groupIdentifier` | `"group.Silent-Net.SilentX"` | App Group ID |
| `sharedDirectory` | `~/Library/Group Containers/{group}/` | Shared container root |
| `sharedConfigPath` | `{shared}/active-config.json` | Active sing-box config |
| `sharedSettingsPath` | `{shared}/settings.db` | Shared preferences |
| `cacheDirectory` | `{shared}/Library/Caches/` | Cache files |
| `workingDirectory` | `{cache}/Working/` | Runtime working dir |

---

## Entity Relationships

```
Profile (SwiftData)
    │
    │ 1:1 (selected)
    ├─── preferredEngine: EngineType
    │
    ▼
ConnectionService
    │
    │ creates based on preferredEngine
    │
    ├──▶ LocalProcessEngine
    │       │
    │       └── Uses sudo/osascript
    │
    └──▶ NetworkExtensionEngine
            │
            ├── ExtensionProfile (VPN manager)
            │       │
            │       └── NETunnelProviderManager
            │               │
            │               └── IPC ────────────────▶ PacketTunnelProvider
            │                                               │
            │                                               └── Libbox
            │
            └── SystemExtension (installer)
                    │
                    └── OSSystemExtensionRequest
```

---

## Storage Strategy

| Entity | Storage | Reason |
|--------|---------|--------|
| ProxyEngine | In-memory | Runtime service |
| ConnectionStatus | In-memory | Transient state |
| ExtensionProfile | In-memory + System Prefs | VPN profile stored by macOS |
| SystemExtension | In-memory + System | Extension managed by macOS |
| Active config | App Group file | Shared with extension |
| Profile | SwiftData | User data persistence |

---

## Concurrency Considerations

- All engine operations are `async`
- Status updates published on `MainActor`
- System extension requests use `DispatchSemaphore` (off main thread)
- NEVPNStatusDidChange notifications on main queue
- Libbox callbacks may come from background threads → dispatch to main

---

## Validation Rules Summary

| Entity | Rule |
|--------|------|
| ProxyConfiguration | Config file must exist, core binary must be executable |
| NetworkExtensionEngine.start() | System extension must be installed |
| ExtensionProfile.start() | VPN profile must be saved to preferences |
| PacketTunnelProvider | Config must be readable from App Group |

# Data Model: Privileged Helper Service IPC Types

## Overview

定义 SilentX App 与 silentx-service 之间的 IPC 通信数据类型。

## IPC Command Types

### IPCCommand (Request)

```swift
/// IPC 命令请求
enum IPCCommand: Codable {
    case start(StartRequest)
    case stop
    case status
    case version
    
    var commandName: String {
        switch self {
        case .start: return "start"
        case .stop: return "stop"
        case .status: return "status"
        case .version: return "version"
        }
    }
}

/// 启动请求参数
struct StartRequest: Codable {
    let configPath: String           // sing-box 配置文件路径
    let corePath: String             // sing-box 二进制路径
    let workingDir: String?          // 工作目录（可选，默认为 dirname(configPath)）
    let logLevel: String?            // 日志级别（可选，默认 info）

    // Optional: client intent derived from config for Apple platforms.
    // If provided, the service should apply system proxy at start and restore at stop.
    let systemProxy: SystemProxyRequest?
}

/// System proxy settings request.
/// Source of truth: sing-box config's `tun.platform.http_proxy` (client-side responsibility).
struct SystemProxyRequest: Codable {
    let enabled: Bool
    let host: String
    let port: Int
    let bypassDomains: [String]?
    let matchDomains: [String]?
}
```

### IPCResponse (Response)

```swift
/// IPC 响应
struct IPCResponse: Codable {
    let code: Int                    // 0 = success, >0 = error
    let message: String?             // 人类可读消息
    let data: ResponseData?          // 响应数据
    
    /// 是否成功
    var isSuccess: Bool { code == 0 }
}

/// 响应数据（根据命令不同）
enum ResponseData: Codable {
    case start(StartData)
    case status(StatusData)
    case version(VersionData)
    case empty
}

/// 启动成功响应
struct StartData: Codable {
    let pid: Int32                   // sing-box 进程 ID
    let startTime: Date              // 启动时间
}

/// 状态查询响应
struct StatusData: Codable {
    let running: Bool                // 是否运行中
    let pid: Int32?                  // 进程 ID（运行时有效）
    let startTime: Date?             // 启动时间
    let configPath: String?          // 当前配置路径
    let uptime: TimeInterval?        // 运行时长（秒）
}

/// 版本信息响应
struct VersionData: Codable {
    let serviceVersion: String       // 服务版本
    let protocolVersion: String      // IPC 协议版本
    let buildDate: String?           // 构建日期
}
```

## Error Codes

```swift
/// IPC 错误码
enum IPCErrorCode: Int, Codable {
    case success = 0                 // 成功
    case generalError = 1            // 一般错误
    case configNotFound = 2          // 配置文件不存在
    case coreNotFound = 3            // 核心二进制不存在
    case alreadyRunning = 4          // 已经在运行
    case notRunning = 5              // 没有在运行
    case startFailed = 6             // 启动失败
    case stopFailed = 7              // 停止失败
    case invalidRequest = 8          // 无效请求
    case permissionDenied = 9        // 权限不足
    case internalError = 10          // 内部错误
}
```

## Service Paths

```swift
/// 服务相关路径
struct ServicePaths {
    /// 服务二进制安装位置
    static let serviceBinary = "/Library/PrivilegedHelperTools/silentx-service"
    
    /// LaunchDaemon plist 位置
    static let launchdPlist = "/Library/LaunchDaemons/com.silentnet.silentx.service.plist"
    
    /// 服务标识符
    static let serviceIdentifier = "com.silentnet.silentx.service"
    
    /// IPC Socket 目录
    static let socketDir = "/tmp/silentx"
    
    /// IPC Socket 路径
    static let socketPath = "/tmp/silentx/silentx-service.sock"
    
    /// 服务日志路径
    static let logPath = "/tmp/silentx/service.log"
}
```

## Service Status Model

```swift
/// 服务安装状态
enum ServiceInstallStatus {
    case notInstalled                // 未安装
    case installed                   // 已安装
    case needsUpdate(current: String, available: String)  // 需要更新
    case broken(reason: String)      // 损坏
}

/// 服务运行状态
enum ServiceRunStatus {
    case running                     // 正在运行
    case stopped                     // 已停止
    case unknown                     // 未知
}

/// 完整服务状态
struct ServiceStatus {
    let installStatus: ServiceInstallStatus
    let runStatus: ServiceRunStatus
    let version: String?
    let lastError: String?
}
```

## IPC Client Error Types

```swift
/// IPC 客户端错误
enum IPCError: LocalizedError {
    case socketCreationFailed
    case connectionFailed
    case sendFailed(Error)
    case receiveFailed
    case decodingFailed(Error)
    case serviceNotAvailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .connectionFailed:
            return "Failed to connect to service"
        case .sendFailed(let error):
            return "Failed to send command: \(error.localizedDescription)"
        case .receiveFailed:
            return "Failed to receive response"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serviceNotAvailable:
            return "Service is not available"
        case .timeout:
            return "Request timed out"
        }
    }
}
```

## Wire Format

IPC 使用 JSON 格式通过 Unix Socket 传输：

### Request Format

```json
{
    "command": "start",
    "payload": {
        "configPath": "/Users/user/Library/Application Support/Silent-Net.SilentX/profiles/xxx.json",
        "corePath": "/Users/user/Library/Application Support/Silent-Net.SilentX/cores/1.9.0/sing-box",
        "logLevel": "info"
    }
}
```

### Response Format

```json
{
    "code": 0,
    "message": "Started successfully",
    "data": {
        "type": "start",
        "pid": 12345,
        "startTime": "2024-12-13T10:30:00Z"
    }
}
```

### Error Response

```json
{
    "code": 6,
    "message": "Failed to start: config validation failed",
    "data": null
}
```

## Relationship Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         SilentX App                          │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────┐    │
│  │ ServiceStatus   │    │      IPCCommand             │    │
│  │ - installStatus │    │ - start(StartRequest)       │    │
│  │ - runStatus     │    │ - stop                      │    │
│  │ - version       │    │ - status                    │    │
│  └────────┬────────┘    │ - version                   │    │
│           │             └──────────────┬──────────────┘    │
│           │                            │                    │
│           ▼                            ▼                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    IPCClient                         │   │
│  │  - send(IPCCommand) async throws -> IPCResponse      │   │
│  │  - isServiceAvailable() -> Bool                      │   │
│  └──────────────────────────┬──────────────────────────┘   │
└─────────────────────────────┬───────────────────────────────┘
                              │ Unix Socket
                              │ /tmp/silentx/silentx-service.sock
┌─────────────────────────────▼───────────────────────────────┐
│                      silentx-service                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    IPCServer                         │   │
│  │  - handleCommand(IPCCommand) -> IPCResponse          │   │
│  └──────────────────────────┬──────────────────────────┘   │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   CoreManager                        │   │
│  │  - start(configPath, corePath) -> IPCResponse        │   │
│  │  - stop() -> IPCResponse                             │   │
│  │  - status() -> StatusData                            │   │
│  │  - process: Process?                                 │   │
│  │  - pid: Int32                                        │   │
│  └──────────────────────────┬──────────────────────────┘   │
│                              │                              │
│                              ▼                              │
│                       ┌───────────┐                         │
│                       │  sing-box │                         │
│                       │  process  │                         │
│                       └───────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

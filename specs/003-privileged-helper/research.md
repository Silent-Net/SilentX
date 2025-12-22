# Research: Privileged Helper Service Implementation

**Feature**: 003-privileged-helper | **Date**: 2025-12-14

## Overview

本文档记录了实现 macOS LaunchDaemon + Unix Socket IPC 的技术调研，并补充了与 sing-box 在 macOS 上的“流量接管”关键点：

- `tun` inbound 仅创建接口并不会自动让系统流量走代理；是否接管取决于 `auto_route` 或系统代理设置。
- `tun.platform.http_proxy` 是给 **图形客户端/管理端** 用来设置系统 HTTP(S) 代理的提示，sing-box 本身不保证自动修改系统代理。
- 将“runtime config”写到不同目录，会改变 sing-box 的工作目录与相对资源（规则、UI、geo 数据）的解析行为，可能导致“进程在跑，但功能不可用”。

---

## 1. macOS 后台服务方案对比

### 1.1 可选方案

| 方案 | 权限模型 | 复杂度 | 适用场景 |
|------|---------|--------|----------|
| osascript 每次提权 | 每次操作需密码 | 低 | 当前方案，用户体验差 |
| SMAppService | App 沙盒内 | 中 | 不支持 root 操作 |
| **LaunchDaemon** | root 常驻，安装时一次密码 | 中 | ✅ 我们的选择 |
| Privileged Helper Tool (XPC) | Apple 官方推荐 | 高 | 需要 Apple 开发者证书 |

### 1.2 选择 LaunchDaemon 的理由

- **用户体验**: 只需一次密码，之后永久免密
- **技术可行**: clash-verge-rev 已验证可行
- **无需证书**: 不需要 Apple 开发者付费账号
- **社区实践**: 多个知名开源项目采用此方案

---

## 2. sing-box on macOS: TUN、auto_route 与系统代理的真实关系

### 2.1 关键结论（用于解释“服务启动成功但 YouTube 打不开”）

来自 sing-box 官方文档：

- `tun.auto_route`: “Set the default route to the Tun.”
    - 当 `auto_route=false` 时，TUN 不会自动成为默认路由；此时除非你另外设置系统代理/路由，否则大多数系统流量不会被接管。
- `tun.platform.http_proxy`: “System HTTP proxy settings.”
    - 这是 **客户端应当应用的系统代理配置**（server/server_port/bypass/match）；仅仅写在 config 里不等价于 macOS 已经启用了系统代理。
- `mixed.set_system_proxy` (macOS 支持): sing-box 可在 mixed inbound 上自动设置系统代理并在退出时清理。

在实际调试中，用户 profile 的 runtime config 为：

- `inbounds = [ { type: "tun", auto_route: false, platform.http_proxy.enabled: true, server_port: 2089 } ]`

这解释了“看起来 TUN 启动了（utun 存在），但系统应用/YouTube 仍不可用”：没有默认路由，也没有系统代理。

### 2.2 决策：SilentX 必须显式承担“系统代理应用”责任

Decision: **当配置包含 `tun.platform.http_proxy.enabled=true` 时，SilentX 必须在连接时为当前网络服务应用 macOS 系统代理设置，并在断开时恢复。**

Rationale:
- 这与 sing-box 的“platform”语义一致：这是给客户端/图形端的指令，而不是 core 的自动行为。
- 可以做到真正的“用户点击 Connect 后系统可用”，不会被 `auto_route=false` 这种配置坑死。
- 在 Privileged Helper 模式下，所有需要管理员权限的系统更改都可由 root daemon 执行，保持“免密码”。

Alternatives considered:
- **强制改写 config：把 `tun.auto_route` 改成 true**。
    - Rejected: 破坏“UI == 终端 config”的等价性；而且会引入路由冲突/loop 风险，需要额外配置 `route.auto_detect_interface`。
- **在 runtime config 注入 mixed inbound 并设置 `set_system_proxy=true`**。
    - Rejected: 仍属于 config 变更；并且需要决定端口、认证、清理策略。
- **要求用户自己在系统设置里手动设置 HTTP/HTTPS 代理**。
    - Rejected: 违背产品目标（成熟工具体验），且错误不可理解。

Implementation notes:
- 优先由 `silentx-service` 执行 system proxy 变更（root 权限，免密码），主 App 仅发出“应用/恢复代理”命令。
- 需要记录“恢复所需的原始系统代理状态”，保证 teardown 干净（Constitution: clean state）。

## 3. runtime config 的工作目录与相对资源（rule-set / external_ui）

### 3.1 问题

如果将 runtime config 写到 `~/Library/Application Support/Silent-Net.SilentX/runtime/`，sing-box 的 working directory 通常也会变成该目录。
但很多订阅/模板配置会使用相对路径（例如 `experimental.clash_api.external_ui = "ui"` 或本地规则文件），这会导致：

- `sing-box check` 可能通过（因为不验证资源存在或下载延后），但运行期功能缺失；
- clash api UI 资源无法加载；
- 规则/geo 数据的下载缓存位置变化，导致行为与终端运行不一致。

### 3.2 决策：保持 runtime config 与 profile config 同目录（或显式设置 workingDir）

Decision: **runtime config 必须和 profile config 同目录，或显式将 workingDir 设置为 profile 目录（而不是 runtime 目录）。**

Rationale:
- 这是最接近终端语义：`sing-box run -c <path/to/config.json>` 通常需要以 config 目录为工作目录来解析相对资源。
- 允许保持“profile 原始 JSON 不变”的同时，避免资源解析偏差。

Alternatives considered:
- 将所有资源复制到 runtime 目录。
    - Rejected: 复杂度高，难以覆盖所有相对资源形式。

Implementation notes:
- IPC 的 `start` 命令应携带 `workingDir` 字段（若未提供，服务端应默认使用 `dirname(configPath)`）。
- 服务端应将 sing-box 运行时的 stdout/stderr 持久化到固定 log，供 UI 诊断。

## 2. clash-verge-rev 实现分析

### 2.1 架构概览

来源: [clash-verge-rev/service.rs](https://github.com/clash-verge-rev/clash-verge-rev)

```
┌─────────────────────┐         ┌──────────────────────┐
│  Tauri App (User)   │  IPC    │  clash-verge-service │
│                     │ ──────► │  (Root LaunchDaemon) │
│  - Rust backend     │ Socket  │  - Process manager   │
│  - TypeScript UI    │         │  - Unix Socket       │
└─────────────────────┘         └──────────────────────┘
```

### 2.2 关键文件结构

```
src-service/
├── Cargo.toml
├── src/
│   ├── main.rs          # 服务入口
│   ├── ipc.rs           # IPC 处理
│   ├── manager.rs       # 进程管理
│   └── cmds/
│       ├── install.rs   # macOS 安装逻辑
│       ├── uninstall.rs # macOS 卸载逻辑
│       └── ...
```

### 2.3 安装脚本核心逻辑

```rust
// src-service/src/cmds/install.rs
#[cfg(target_os = "macos")]
pub fn install_service() {
    // 1. 复制服务到系统目录
    let target_path = "/Library/PrivilegedHelperTools/io.github.clash-verge-rev.clash-verge-service";
    std::fs::copy(&current_exe, &target_path);
    
    // 2. 设置权限
    std::process::Command::new("chmod")
        .args(["544", target_path])
        .status();
    std::process::Command::new("chown")
        .args(["root:wheel", target_path])
        .status();
    
    // 3. 创建 plist
    let plist_content = r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.github.clash-verge-rev.clash-verge-service</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/io.github.clash-verge-rev.clash-verge-service</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>"#;
    std::fs::write("/Library/LaunchDaemons/io.github.clash-verge-rev.clash-verge-service.plist", plist_content);
    
    // 4. 注册并启动服务
    std::process::Command::new("launchctl")
        .args(["bootstrap", "system", "/Library/LaunchDaemons/io.github.clash-verge-rev.clash-verge-service.plist"])
        .status();
    std::process::Command::new("launchctl")
        .args(["enable", "system/io.github.clash-verge-rev.clash-verge-service"])
        .status();
}
```

### 2.4 IPC 通信

```rust
// Socket 路径
#[cfg(target_os = "macos")]
const IPC_PATH: &str = "/tmp/clash-verge-service.sock";

// 命令格式
enum ServiceCommand {
    StartClash { config_dir: PathBuf },
    StopClash,
    GetClashStatus,
}

// 响应格式
struct ServiceResponse {
    code: i32,
    data: Option<String>,
    error: Option<String>,
}
```

---

## 3. Unix Socket 技术细节

### 3.1 创建 Socket (服务端)

```swift
import Foundation

let socketPath = "/tmp/silentx/silentx-service.sock"

// 1. 创建 socket
let fd = socket(AF_UNIX, SOCK_STREAM, 0)

// 2. 绑定地址
var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
socketPath.withCString { ptr in
    withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
        _ = strcpy(dest, ptr)
    }
}

let bindResult = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}

// 3. 设置权限 (让普通用户可访问)
chmod(socketPath, 0o666)

// 4. 监听
listen(fd, 5)

// 5. 接受连接
while true {
    let clientFd = accept(fd, nil, nil)
    // 处理请求...
}
```

### 3.2 连接 Socket (客户端)

```swift
import Foundation

let socketPath = "/tmp/silentx/silentx-service.sock"

// 1. 创建 socket
let fd = socket(AF_UNIX, SOCK_STREAM, 0)

// 2. 连接
var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
socketPath.withCString { ptr in
    withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
        _ = strcpy(dest, ptr)
    }
}

let connectResult = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}

// 3. 发送/接收数据
let message = "{\"command\":\"status\"}"
_ = message.withCString { ptr in
    write(fd, ptr, strlen(ptr))
}

var buffer = [CChar](repeating: 0, count: 4096)
let bytesRead = read(fd, &buffer, buffer.count)
let response = String(cString: buffer)

// 4. 关闭
close(fd)
```

### 3.3 Swift Network Framework 替代方案

```swift
import Network

// 使用 NWConnection 更现代的 API
let connection = NWConnection(
    to: .unix(path: "/tmp/silentx/silentx-service.sock"),
    using: .tcp
)

connection.stateUpdateHandler = { state in
    switch state {
    case .ready:
        // 发送数据
        connection.send(content: data, completion: .contentProcessed { error in
            // 处理发送结果
        })
    case .failed(let error):
        print("Connection failed: \(error)")
    default:
        break
    }
}

connection.start(queue: .global())
```

---

## 4. launchd 详解

### 4.1 LaunchDaemon vs LaunchAgent

| 类型 | 位置 | 运行用户 | 启动时机 |
|------|------|---------|----------|
| LaunchDaemon | `/Library/LaunchDaemons/` | root | 系统启动 |
| LaunchAgent | `~/Library/LaunchAgents/` | 当前用户 | 用户登录 |

我们需要 **LaunchDaemon** 因为要以 root 权限运行。

### 4.2 Plist 关键字段

```xml
<dict>
    <!-- 唯一标识符 -->
    <key>Label</key>
    <string>com.silentnet.silentx.service</string>
    
    <!-- 可执行文件路径 -->
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/silentx-service</string>
    </array>
    
    <!-- 系统启动时自动运行 -->
    <key>RunAtLoad</key>
    <true/>
    
    <!-- 崩溃后自动重启 -->
    <key>KeepAlive</key>
    <true/>
    
    <!-- 日志输出 -->
    <key>StandardOutPath</key>
    <string>/tmp/silentx/service.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/silentx/service.log</string>
    
    <!-- 工作目录 -->
    <key>WorkingDirectory</key>
    <string>/tmp/silentx</string>
</dict>
```

### 4.3 launchctl 命令

```bash
# 加载并注册服务 (需要 root)
sudo launchctl bootstrap system /Library/LaunchDaemons/com.silentnet.silentx.service.plist

# 启用服务
sudo launchctl enable system/com.silentnet.silentx.service

# 启动服务 (如果没有 RunAtLoad)
sudo launchctl kickstart system/com.silentnet.silentx.service

# 停止服务
sudo launchctl kickstart -k system/com.silentnet.silentx.service

# 卸载服务
sudo launchctl bootout system/com.silentnet.silentx.service

# 查看服务状态
sudo launchctl list | grep silentx

# 查看服务详情
sudo launchctl print system/com.silentnet.silentx.service
```

---

## 5. 安全考虑

### 5.1 Socket 权限

**问题**: 服务以 root 运行，但普通用户 App 需要连接 socket

**解决**: 设置 socket 权限为 `0666` (世界可读写)

```swift
chmod(socketPath, 0o666)
```

**风险评估**: 低风险，因为:
- Socket 只控制本地代理
- 不传输敏感信息（配置文件路径不算敏感）
- 任何进程都可以启停代理，但这只影响本机网络

### 5.2 路径验证

服务必须验证所有输入路径:

```swift
func validatePath(_ path: String) -> Bool {
    // 检查文件存在
    guard FileManager.default.fileExists(atPath: path) else {
        return false
    }
    
    // 可选: 限制只能访问特定目录
    let allowedPrefixes = [
        "/Users/",
        "/Library/Application Support/"
    ]
    
    return allowedPrefixes.contains { path.hasPrefix($0) }
}
```

### 5.3 进程隔离

- 服务只管理 sing-box 进程
- 不执行任意命令
- 不访问用户敏感数据

---

## 6. 错误处理策略

### 6.1 服务崩溃

launchd `KeepAlive` 会自动重启服务。App 检测到连接失败时:

1. 等待 1-2 秒让服务重启
2. 重试连接
3. 如果持续失败，提示用户重装服务

### 6.2 sing-box 崩溃

服务内部监控 sing-box 进程:

```swift
actor CoreManager {
    func monitorProcess() async {
        guard let process = self.process else { return }
        
        process.terminationHandler = { [weak self] proc in
            Task {
                await self?.handleProcessTermination(exitCode: proc.terminationStatus)
            }
        }
    }
    
    func handleProcessTermination(exitCode: Int32) {
        // 更新状态
        self.process = nil
        self.pid = 0
        
        // 日志记录
        log("sing-box exited with code: \(exitCode)")
    }
}
```

### 6.3 版本不匹配

IPC 协议包含版本号:

```swift
struct IPCRequest: Codable {
    let protocolVersion: Int = 1
    let command: IPCCommand
    let payload: [String: String]
}

// 服务端检查版本
func handleRequest(_ request: IPCRequest) -> IPCResponse {
    guard request.protocolVersion == SUPPORTED_VERSION else {
        return IPCResponse(
            success: false,
            error: "VERSION_MISMATCH",
            message: "Please update SilentX to the latest version"
        )
    }
    // ...
}
```

---

## 7. 决策记录

### Decision 1: 使用 LaunchDaemon 而非 XPC Service

**选择**: LaunchDaemon + Unix Socket  
**原因**: 
- 不需要 Apple 开发者付费账号
- clash-verge-rev 已验证可行
- 实现复杂度适中

**替代方案**: SMAppService (不支持 root)、Privileged Helper Tool (需要证书)

### Decision 2: 服务使用 Swift 而非 Go/Rust

**选择**: Swift  
**原因**:
- 与主 App 代码库一致
- 减少构建复杂度
- macOS API 原生支持

**替代方案**: 
- Rust (clash-verge-rev 使用): 跨平台但增加复杂度
- Go (sing-box 本身): 需要 cgo 调用 macOS API

### Decision 3: JSON-over-Socket 而非二进制协议

**选择**: JSON  
**原因**:
- 易于调试 (可用 socat 测试)
- Swift 原生 Codable 支持
- 性能足够 (本地通信)

**替代方案**: Protocol Buffers (过度设计)、MessagePack (复杂度高)

---

### Decision 4: 对 `tun.platform.http_proxy` 进行系统代理应用/恢复

**选择**: SilentX 在连接时应用系统代理、断开时恢复（优先由 root service 执行）

**原因**:
- 避免 `auto_route=false` 的 tun-only 配置导致“看似已连接但无法上网”。
- 让用户体验与成熟客户端一致。

**替代方案**: 强制 `auto_route=true` / 注入 mixed+set_system_proxy / 让用户手动配置（均不满足目标）。

### Decision 5: runtime config 的工作目录必须与 profile 目录一致

**选择**: runtime config 与 profile 同目录或显式 workingDir

**原因**:
- 避免相对资源解析差异（规则、UI、geo 数据）。

**替代方案**: 复制资源到 runtime 目录（复杂度过高）。

## 8. 参考资料

1. [clash-verge-rev 源码](https://github.com/clash-verge-rev/clash-verge-rev)
2. [Apple launchd.plist 文档](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
3. [Unix Domain Socket 教程](https://beej.us/guide/bgipc/html/single/bgipc.html#unixsock)
4. [launchctl 手册](https://www.manpagez.com/man/1/launchctl/)

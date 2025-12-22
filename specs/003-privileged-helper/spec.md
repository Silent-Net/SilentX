# Feature Specification: Privileged Helper Service - 免密码代理管理

**Feature Branch**: `003-privileged-helper`  
**Created**: 2025-12-12  
**Status**: Draft  
**Input**: User description: "实现和 Clash Verge Rev 一样的体验 - 创建 Privileged Helper 服务，一个独立的命令行程序 silentx-service 负责启动/停止 sing-box 进程；安装脚本将服务安装到 PrivilegedHelperTools，创建 LaunchDaemon plist 到 LaunchDaemons，只需要一次 admin 密码；IPC 通信主 App 通过 Unix Socket 与服务通信，发送启动/停止/获取状态等命令"

## User Scenarios & Testing *(mandatory)*

## Definition: “代理可用 / Proxy Works” *(mandatory)*

To avoid ambiguity, SilentX defines “proxy works” as one of the following **explicitly verifiable** outcomes:

1. **System Proxy Mode (recommended for `tun` + `auto_route=false`)**
	- macOS System HTTP and HTTPS proxy are set to `127.0.0.1:<port>` where `<port>` comes from sing-box config (`tun.platform.http_proxy.server_port` when present, otherwise from a local `mixed/http` inbound).
	- On disconnect/crash, the original proxy settings are restored.

2. **Auto-Route Mode (`tun.auto_route=true`)**
	- sing-box creates the TUN interface and system default route is taken over by the TUN (verified via `route -n get default`).
	- SilentX does not modify system proxy settings.

If the config is `tun`-only with `auto_route=false` and does not provide a client-side proxy hint, SilentX must surface a clear actionable error (see FR-013/FR-014).

### User Story 1 - 一键无密码连接代理 (Priority: P1)

作为用户，我希望在安装服务后，每次启动代理时不再需要输入密码，只需点击连接按钮即可立即启动 sing-box 代理。

**Why this priority**: 这是核心用户痛点 - 当前每次启动都需要输入密码，严重影响用户体验。解决此问题后，用户体验将与 Clash Verge Rev 等成熟工具持平。

**Independent Test**: 安装服务后，点击"连接"按钮 → sing-box 进程启动 → Proxy Works（见上文定义）→ 全程无密码提示

**Acceptance Scenarios**:

1. **Given** 服务已安装且正在运行, **When** 用户点击"连接"按钮, **Then** sing-box 在 2 秒内启动，无密码提示
2. **Given** 代理已连接, **When** 用户点击"断开"按钮, **Then** sing-box 进程优雅终止，无密码提示
3. **Given** 服务已安装, **When** 用户重启电脑后打开 App, **Then** 服务自动运行，用户可直接连接代理

4. **Given** 配置为 `tun` 且 `auto_route=false` 并包含 `tun.platform.http_proxy.enabled=true`, **When** 用户点击"连接", **Then** 连接成功后系统 HTTP/HTTPS 代理被设置为 `127.0.0.1:<port>` 且断开后自动恢复

---

### User Story 2 - 一次性服务安装 (Priority: P1)

作为用户，我希望通过简单的操作（仅需一次密码）完成服务的安装，之后的所有代理操作都不再需要密码。

**Why this priority**: 这是实现免密码体验的前提条件，与 US1 同等重要。用户需要清晰的引导完成服务安装。

**Independent Test**: 点击"安装服务"按钮 → 输入一次管理员密码 → 服务安装成功 → 后续操作无需密码

**Acceptance Scenarios**:

1. **Given** 服务未安装, **When** 用户点击"安装服务"按钮并输入管理员密码, **Then** 服务安装到系统位置并启动
2. **Given** 服务安装失败, **When** 安装过程出错, **Then** 显示清晰的错误信息和解决建议
3. **Given** 服务已安装, **When** 用户再次点击"安装服务", **Then** 提示服务已安装或自动更新服务

---

### User Story 3 - 服务状态监控 (Priority: P2)

作为用户，我希望能看到服务的运行状态，知道是否已安装、是否正在运行，以便排查问题。

**Why this priority**: 帮助用户理解系统状态，在出现问题时提供诊断信息。

**Independent Test**: 打开设置页面 → 查看服务状态指示器 → 显示"已安装/运行中"或"未安装"

**Acceptance Scenarios**:

1. **Given** 服务已安装且运行, **When** 用户查看设置页面, **Then** 显示绿色状态指示器和"服务运行中"
2. **Given** 服务已安装但停止, **When** 用户查看设置页面, **Then** 显示黄色状态指示器和"服务已停止"
3. **Given** 服务未安装, **When** 用户查看设置页面, **Then** 显示灰色状态指示器和"服务未安装"，提供安装按钮

---

### User Story 4 - 服务卸载 (Priority: P3)

作为用户，我希望能够卸载服务，恢复到之前的状态，或者在出现问题时重新安装。

**Why this priority**: 提供完整的服务生命周期管理，增强用户控制感。

**Independent Test**: 点击"卸载服务"按钮 → 输入管理员密码 → 服务被移除 → 回退到密码模式

**Acceptance Scenarios**:

1. **Given** 服务已安装, **When** 用户点击"卸载服务"并确认, **Then** 服务从系统中移除，App 回退到密码模式
2. **Given** 代理正在运行, **When** 用户尝试卸载服务, **Then** 提示先断开代理连接

---

### User Story 5 - sing-box 进程状态同步 (Priority: P2)

作为用户，我希望 App 能准确反映 sing-box 进程的真实状态，包括异常退出时的通知。

**Why this priority**: 确保 UI 状态与实际进程状态一致，避免用户困惑。

**Independent Test**: 强制终止 sing-box 进程 → App 检测到状态变化 → 更新 UI 显示为"已断开"

**Acceptance Scenarios**:

1. **Given** sing-box 通过服务启动, **When** sing-box 异常退出, **Then** App 在 3 秒内检测到并更新状态
2. **Given** App 启动, **When** 服务中有正在运行的 sing-box, **Then** App 自动同步为"已连接"状态

---

### User Story 6 - TUN 生效（系统代理自动设置）(Priority: P1)

作为用户，我希望在 tun-only 且 `auto_route=false` 的配置下，SilentX 能自动设置系统代理，保证系统应用（如 Safari/YouTube）真实走代理。

**Independent Test**: 使用 tun-only 配置（`auto_route=false`，`tun.platform.http_proxy.enabled=true`）→ 点击连接 → 系统代理自动设置 → 系统应用可访问 → 断开后系统代理恢复

**Acceptance Scenarios**:

1. **Given** tun-only + `auto_route=false` + `tun.platform.http_proxy.enabled=true`, **When** 连接成功, **Then** 系统 HTTP/HTTPS 代理设置为 `127.0.0.1:<port>`
2. **Given** 已连接且系统代理已设置, **When** sing-box 异常退出, **Then** SilentX 在 3 秒内检测到并恢复系统代理为原始值
3. **Given** 用户切换到另一个配置文件（不同端口）, **When** SilentX 切换成功, **Then** 系统代理端口同步更新且旧进程/旧代理状态不会残留

---

### Edge Cases

- 服务安装时用户取消密码输入会发生什么？→ 显示"安装已取消"提示，保持当前状态
- 服务运行但 IPC 通信失败怎么办？→ 显示"服务通信失败"错误，提供重试或重装选项
- 用户手动删除 LaunchDaemon plist 后会怎样？→ 检测到服务异常，提示重新安装
- sing-box 配置文件无效导致启动失败？→ 服务返回错误信息，App 显示具体错误原因
- 系统升级后服务权限丢失？→ 检测到服务状态异常，提示重新安装

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统必须提供独立的 `silentx-service` 命令行程序作为 Privileged Helper
- **FR-002**: 服务必须以 LaunchDaemon 形式安装到 `/Library/LaunchDaemons/`
- **FR-003**: 服务二进制必须安装到 `/Library/PrivilegedHelperTools/`
- **FR-004**: 服务必须以 root 权限运行并在系统启动时自动加载
- **FR-005**: 服务必须通过 Unix Socket 提供 IPC 通信接口
- **FR-006**: IPC 接口必须支持：启动 sing-box、停止 sing-box、获取状态、获取版本
- **FR-007**: 服务必须监控 sing-box 进程状态并通过 IPC 报告
- **FR-008**: 安装/卸载脚本必须通过 `osascript` 提示管理员密码
- **FR-009**: App 必须能检测服务是否已安装和运行
- **FR-010**: App 必须在服务不可用时回退到现有的密码模式（sudo/osascript）
- **FR-011**: 服务必须支持同时管理多个配置文件的切换
- **FR-012**: 服务必须记录操作日志用于问题诊断

- **FR-013**: 当配置为 `tun` 且 `auto_route=false` 且包含 `tun.platform.http_proxy.enabled=true` 时，系统必须在连接后自动设置 macOS 系统 HTTP/HTTPS 代理以实现 Proxy Works
- **FR-014**: 系统必须在断开连接、服务崩溃或 sing-box 异常退出时，确保系统代理/网络状态被可靠恢复（无残留代理设置、无孤儿进程）

**FR-011 Clarification**: “切换”指在已有连接时切换到另一个 Profile/Config：必须先停止旧 sing-box（并清理旧的系统代理状态），再启动新 sing-box，并更新状态为新配置。

### Key Entities

- **SilentXService**: Privileged Helper 守护进程，负责以 root 权限管理 sing-box 生命周期
- **ServiceInstaller**: 安装/卸载逻辑，处理权限提升和系统文件操作
- **IPCClient**: 主 App 中的 IPC 客户端，通过 Unix Socket 与服务通信
- **IPCServer**: 服务端 IPC 处理器，解析命令并执行相应操作
- **ServiceStatus**: 服务状态模型，包含安装状态、运行状态、版本信息

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 服务安装后，用户启动/停止代理的全过程无需任何密码输入
- **SC-002**: 从点击"连接"到 sing-box 进程启动完成在 2 秒内
- **SC-003**: 服务在系统重启后自动恢复运行，无需用户干预
- **SC-004**: App 能在 3 秒内检测到 sing-box 进程的异常终止
- **SC-005**: 服务安装/卸载操作各只需要一次密码输入
- **SC-006**: IPC 通信延迟在本地环境下不超过 100ms
- **SC-007**: 服务内存占用在空闲时不超过 10MB

- **SC-008**: 在满足 FR-013 的配置下，连接后 3 秒内系统代理状态与配置一致；断开/崩溃后 3 秒内恢复原始状态

## Assumptions

- macOS 版本 >= 10.15 (Catalina) 支持 LaunchDaemon
- 用户有管理员权限可以安装服务
- sing-box 二进制文件已存在于 App 支持目录中
- 参考实现：Clash Verge Rev 的 `clash-verge-service-ipc` 方案

## Out of Scope

- iOS/iPadOS 支持（这些平台使用 Network Extension）
- Windows/Linux 支持（将来可能扩展）
- 服务的自动更新机制（可在后续迭代中添加）
- 多用户环境下的服务隔离

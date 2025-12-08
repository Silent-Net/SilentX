# Feature Specification: Sudo Proxy Refactor - 代理方案重构

**Feature Branch**: `002-sudo-proxy-refactor`
**Created**: 2025-12-07
**Status**: Draft
**Input**: 重构代理方案，采用sudo授权作为首选策略（类似 ClashX Pro）以启动 sing-box，保持架构可替换，后续可选支持 Network Extension。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 一键连接代理 (Priority: P1)

用户打开SilentX应用，点击连接按钮后，系统提示输入macOS管理员密码以获取必要权限，授权后代理服务成功启动，所有网络流量按配置规则处理（当前迭代以本地进程模式提供 HTTP/SOCKS，TUN/NE 支持留待后续迭代）。

**Why this priority**: 这是应用的核心功能，没有可靠的代理连接，其他所有功能都毫无意义。当前版本存在"Core process exited during startup"错误，必须首先解决。

**Independent Test**: 可以通过点击Connect按钮并验证代理是否正常工作来独立测试。成功标准：访问被墙网站正常，sing-box进程稳定运行。

**Acceptance Scenarios**:

1. **Given** 用户已安装应用且有可用的配置文件, **When** 用户点击Connect按钮, **Then** 系统弹出macOS密码授权对话框
2. **Given** 用户在授权对话框中输入正确密码, **When** 点击确认, **Then** sing-box内核以管理员权限启动，代理开始工作（当前迭代仅 HTTP/SOCKS，TUN 接口由后续 Network Extension 迭代提供）
3. **Given** 用户在授权对话框中取消, **When** 点击取消按钮, **Then** 系统显示友好提示"需要管理员权限才能启用代理"，不崩溃
4. **Given** 代理正在运行, **When** 用户点击Disconnect, **Then** 代理服务正常停止，系统网络恢复正常

---

### User Story 2 - 代理模式切换 (Priority: P2)

用户可以在设置中选择代理运行模式：使用本地进程模式（sudo，需密码授权）或Network Extension模式（无需密码但需要系统扩展许可）。首选交付本地进程模式，Network Extension 为可选后续迭代。

**Why this priority**: 混合架构允许用户根据场景选择最适合的模式。对于开发者可能更喜欢内核模式调试，普通用户可能更偏好无感的Network Extension模式。

**Independent Test**: 可以在设置界面切换模式并验证代理功能是否正常工作来独立测试。

**Acceptance Scenarios**:

1. **Given** 用户处于设置页面, **When** 选择"内核模式（Sudo）", **Then** 下次连接时使用sudo权限启动sing-box
2. **Given** 用户处于设置页面, **When** 选择"系统扩展模式", **Then** 下次连接时通过Network Extension启动代理
3. **Given** 用户切换了模式, **When** 当前有活跃连接, **Then** 系统提示需要断开当前连接后才能切换模式

---

### User Story 3 - 连接状态监控 (Priority: P3)

用户可以实时查看代理连接状态，包括当前运行模式、连接时长、流量统计，以及任何错误信息的清晰展示。

**Why this priority**: 良好的状态反馈帮助用户了解代理是否正常工作，出问题时能快速定位原因。

**Independent Test**: 可以通过连接代理后观察状态面板信息更新来独立测试。

**Acceptance Scenarios**:

1. **Given** 代理已连接, **When** 用户查看Dashboard, **Then** 显示绿色状态指示、当前模式、连接时长
2. **Given** 连接发生错误, **When** 系统检测到问题, **Then** 显示红色状态和具体错误信息（人类可读）
3. **Given** 代理未连接, **When** 用户查看Dashboard, **Then** 显示灰色状态，Connect按钮可用

---

### Edge Cases

- 用户输入错误密码怎么办？系统应允许重试，3次失败后提示稍后再试
- sing-box进程意外崩溃怎么办？系统应检测到并更新UI状态，提示用户重新连接
- 系统睡眠/唤醒后代理连接状态如何处理？应自动检测并尝试恢复连接
- 用户没有管理员权限怎么办？应提示用户联系管理员或使用Network Extension模式
- 配置文件损坏或无效怎么办？应在连接前验证配置，显示具体错误位置
- Network Extension权限被系统撤销怎么办？应检测并提示用户重新授权

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统必须在启动代理时弹出macOS标准密码授权对话框请求管理员权限（使用 AuthorizationServices，支持重试提示）
- **FR-002**: 系统必须支持两种代理运行模式：本地进程（sudo）模式和Network Extension模式（后者为可选模块，可移除）
- **FR-003**: 系统必须在用户授权后以管理员权限启动sing-box进程（通过受控的 helper/授权调用，避免沙盒限制）
- **FR-004**: 系统必须正确创建和配置TUN网络接口（utun设备）；当前迭代可暂缓至 Network Extension 交付，需在计划与任务中明确阶段
- **FR-005**: 系统必须监控sing-box进程状态，检测意外退出并更新UI
- **FR-006**: 系统必须在断开连接时正确清理资源（停止进程、移除TUN接口、恢复系统网络设置）
- **FR-007**: 系统必须持久化用户选择的代理模式偏好
- **FR-008**: 系统必须在连接前验证配置文件的有效性
- **FR-009**: 系统必须提供清晰的错误信息，帮助用户理解问题原因
- **FR-010**: 系统架构必须支持快速移除或替换 Network Extension 模式（保持代码模块化，默认优先 sudo 引擎）

### Key Entities

- **ProxyEngine**: 代理引擎抽象，定义启动、停止、状态查询的统一接口
- **LocalProcessEngine（sudo）**: 实现通过sudo权限运行sing-box内核的代理引擎
- **NetworkExtensionEngine**: 实现通过系统Network Extension的代理引擎（预留）
- **ConnectionState**: 连接状态模型，包含状态枚举、错误信息、连接时长、流量统计
- **ProxyConfiguration**: 代理配置，包含sing-box配置文件路径、运行模式选择

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 用户点击Connect后，在正确输入密码的情况下，代理应在5秒内成功启动并开始工作
- **SC-002**: 代理连接成功率达到99%以上（排除网络本身问题和配置错误）
- **SC-003**: sing-box进程意外退出时，用户应在2秒内看到错误状态更新
- **SC-004**: 用户可以在30秒内完成从连接到断开的完整操作流程
- **SC-005**: 错误信息的可理解性：用户无需技术背景即可理解错误原因和解决方向
- **SC-006**: 代理模式切换应即时生效（下次连接时）
- **SC-007**: 系统睡眠唤醒后，代理状态应在10秒内自动恢复或更新

## Assumptions

- 用户使用的macOS版本支持AuthorizationServices（macOS 10.7+）
- sing-box二进制文件已正确签名或用户允许运行未签名程序
- 用户拥有macOS管理员账户或知道管理员密码
- Network Extension模式的实现将在后续迭代中完成，当前优先实现Sudo模式
- 用户的sing-box配置文件格式与命令行测试时使用的格式相同
- 沙盒限制可能阻止直接以 root 运行进程，需通过 AuthorizationServices + helper 或等效机制调用

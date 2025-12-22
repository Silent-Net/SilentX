# Feature Specification: Groups Panel - 代理组管理

**Feature Branch**: `004-groups-panel`  
**Created**: 2025-12-13  
**Status**: Draft  
**Input**: User request for Groups view like SFM (sing-box for Mac)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 查看代理组列表 (Priority: P1)

作为用户，我希望能在 Groups 面板中看到所有代理组（如 NodeSelected, Foreign, China 等），了解每个组的类型和当前选中的节点。

**Why this priority**: 核心功能 - 用户需要知道当前使用的代理节点配置。

**Independent Test**: 连接代理后 → 打开 Groups 面板 → 看到所有代理组及其选中状态

**Acceptance Scenarios**:

1. **Given** 代理已连接, **When** 用户打开 Groups 面板, **Then** 显示所有 selector/urltest 类型的出站组
2. **Given** 代理组有多个节点, **When** 用户查看组详情, **Then** 显示所有节点及其延迟数据
3. **Given** 代理未连接, **When** 用户打开 Groups 面板, **Then** 显示"请先连接代理"提示

---

### User Story 2 - 切换代理节点 (Priority: P1)

作为用户，我希望能在 Groups 面板中切换代理组的选中节点，无需重新连接代理。

**Why this priority**: 核心功能 - 用户需要能够灵活切换节点以获得最佳体验。

**Independent Test**: 打开 Groups 面板 → 点击某个节点 → 该节点被选中 → 代理立即生效

**Acceptance Scenarios**:

1. **Given** 用户在 selector 组中, **When** 点击另一个节点, **Then** 该节点被选中并立即生效
2. **Given** urltest 组, **When** 用户尝试切换节点, **Then** 提示此组为自动选择或允许手动覆盖
3. **Given** 节点切换成功, **When** 用户发送请求, **Then** 请求通过新选中的节点

---

### User Story 3 - 测试节点延迟 (Priority: P2)

作为用户，我希望能测试代理组中各节点的延迟，帮助选择最快的节点。

**Why this priority**: 增强体验 - 用户可以根据延迟数据做出更好的选择。

**Independent Test**: 点击测速按钮 → 所有节点开始测速 → 显示延迟结果 → 颜色编码（绿/黄/红）

**Acceptance Scenarios**:

1. **Given** 用户在代理组详情中, **When** 点击测速按钮, **Then** 对该组所有节点执行延迟测试
2. **Given** 测速完成, **When** 显示结果, **Then** 延迟 <300ms 绿色, 300-600ms 黄色, >600ms 红色
3. **Given** 节点不可用, **When** 测速超时, **Then** 显示"超时"或错误状态

---

### User Story 4 - 折叠展开代理组 (Priority: P3)

作为用户，我希望能折叠/展开代理组，在节点很多时保持界面整洁。

**Why this priority**: UI 优化 - 当有大量节点时提升可用性。

**Independent Test**: 点击折叠按钮 → 组收起显示概览 → 再次点击 → 展开显示所有节点

**Acceptance Scenarios**:

1. **Given** 代理组已展开, **When** 点击折叠按钮, **Then** 组收起仅显示名称和节点状态摘要
2. **Given** 代理组已折叠, **When** 点击展开按钮, **Then** 显示组内所有节点详情

---

### Edge Cases

- Clash API 连接失败时显示错误信息并提供重试选项
- 代理断开时自动清空组列表并提示重新连接
- 节点切换期间显示加载状态，防止重复点击
- 大量节点（>100）时支持虚拟滚动或分页
- 测速期间禁止切换节点

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统必须通过 Clash API 获取代理组信息
- **FR-002**: 系统必须显示所有 selector 和 urltest 类型的出站组
- **FR-003**: 系统必须显示每个组内的所有节点及当前选中节点
- **FR-004**: 系统必须支持通过 Clash API 切换 selector 组的选中节点
- **FR-005**: 系统必须支持对组内节点执行延迟测试
- **FR-006**: 系统必须以颜色编码显示节点延迟状态
- **FR-007**: 系统必须支持折叠/展开代理组
- **FR-008**: 系统必须在代理连接时自动刷新组信息
- **FR-009**: 系统必须在侧边栏添加 Groups 导航入口

### Key Entities

- **OutboundGroup**: 代理组模型，包含 tag, type, selected, items
- **OutboundGroupItem**: 代理节点模型，包含 tag, type, delay
- **ClashAPIClient**: Clash API 客户端，负责获取/修改代理组数据
- **GroupsView**: 代理组列表视图
- **GroupDetailView**: 单个代理组详情视图
- **GroupItemView**: 节点选择项视图

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 代理组列表在代理连接后 1 秒内加载完成
- **SC-002**: 节点切换在点击后 500ms 内生效
- **SC-003**: 延迟测试结果在 5 秒内返回（单节点）
- **SC-004**: 支持显示 100+ 节点的代理组而不卡顿
- **SC-005**: Groups 面板与 SFM 功能对齐（组列表、节点切换、延迟测试）

## Technical Notes

### Clash API Endpoints (sing-box)

From config: `experimental.clash_api.external_controller: "127.0.0.1:9099"`

1. **GET /proxies** - 获取所有代理/组信息
2. **GET /proxies/:name** - 获取指定代理详情
3. **PUT /proxies/:name** - 切换 selector 组的选中节点
4. **GET /proxies/:name/delay** - 测试指定节点延迟

### Reference Implementation

SFM (sing-box-for-apple) 使用 Libbox 库连接 sing-box 内部命令服务器。
SilentX 将直接使用 Clash API (HTTP REST API)，更简单且不需要额外依赖。

## Assumptions

- sing-box 配置中已启用 Clash API (`experimental.clash_api.external_controller`)
- Clash API 端口可通过配置文件解析获得
- 代理连接时 Clash API 自动可用

## Out of Scope

- Libbox 集成（使用 Clash API 替代）
- 连接流量详情（将在单独功能中实现）
- 实时日志查看（将在单独功能中实现）
- Clash Mode 切换（将在单独功能中实现）

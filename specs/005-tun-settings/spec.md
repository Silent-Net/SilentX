# Feature Spec: TUN Interface Settings - TUN接口自定义配置

## Overview

允许用户在Settings中自定义TUN接口名称和IP地址，避免与其他代理工具（如SFM、NekoRay）冲突。

## Problem Statement

当用户同时安装多个代理工具时，它们可能使用相同的TUN接口名称和IP地址，导致：
1. 路由冲突 - 默认路由指向错误的TUN接口
2. IP冲突 - 多个接口使用相同的`172.19.0.1`地址
3. 无法正常代理 - 流量被发送到非活动的TUN接口

## Solution

在Settings中提供TUN配置选项，让用户可以自定义：
1. **TUN接口名称** (interface_name): 如 `utun199`, `utun109`, `utun88`
2. **IPv4地址** (address[0]): 如 `10.10.0.1/30`, `172.20.0.1/30`
3. **IPv6地址** (address[1]): 如 `fdfe:dcba:9877::1/126`

## User Stories

### US1: 自定义TUN接口名称
**作为** 一个同时使用多个代理工具的用户
**我想** 为SilentX设置独特的TUN接口名称
**以便** 避免与其他工具的TUN接口冲突

### US2: 自定义TUN IP地址
**作为** 一个高级用户
**我想** 自定义TUN接口的IP地址段
**以便** 避免IP地址冲突并便于调试

### US3: 预设配置选择
**作为** 一个普通用户
**我想** 从预设配置中选择
**以便** 快速设置而无需了解技术细节

## Functional Requirements

### FR1: TUN配置存储
- 存储位置：UserDefaults / @AppStorage
- 配置项：
  - `tunInterfaceName`: String, 默认 "utun199"
  - `tunIPv4Address`: String, 默认 "10.10.0.1/30"  
  - `tunIPv6Address`: String, 默认 "fdfe:dcba:9877::1/126"

### FR2: 配置应用
- 在生成/转换sing-box配置时，将TUN设置注入到`inbounds`中
- 修改`ConnectionService.ensureMixedInbound()`或创建新方法

### FR3: 预设配置
提供预设选项供用户快速选择：

| 预设名称 | 接口名 | IPv4 | IPv6 |
|---------|--------|------|------|
| SilentX默认 | utun199 | 10.10.0.1/30 | fdfe:dcba:9877::1/126 |
| 备选方案A | utun109 | 172.20.0.1/30 | fdfe:dcba:9878::1/126 |
| 备选方案B | utun88 | 192.168.199.1/30 | fdfe:dcba:9879::1/126 |
| 自定义 | (用户输入) | (用户输入) | (用户输入) |

### FR4: 输入验证
- 接口名：必须以`utun`开头，后跟数字（1-999）
- IPv4：必须是有效的CIDR格式私网地址
- IPv6：必须是有效的CIDR格式

## UI Design

### Settings → Proxy Mode → TUN Configuration

```
┌─────────────────────────────────────────────┐
│ TUN Configuration                           │
├─────────────────────────────────────────────┤
│ Preset: [SilentX默认 ▼]                     │
│                                             │
│ Interface Name                              │
│ ┌─────────────────────────────────────────┐ │
│ │ utun199                                 │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ IPv4 Address                                │
│ ┌─────────────────────────────────────────┐ │
│ │ 10.10.0.1/30                            │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ IPv6 Address                                │
│ ┌─────────────────────────────────────────┐ │
│ │ fdfe:dcba:9877::1/126                   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ⚠️ Changes require reconnect to take effect │
└─────────────────────────────────────────────┘
```

## Technical Implementation

### Data Flow
```
User Input → TUNSettings → @AppStorage
                              ↓
ConnectionService.connect() → transformConfig()
                              ↓
                    Inject TUN settings into JSON
                              ↓
                    Write to profile config file
                              ↓
                    sing-box uses custom TUN config
```

### Config Transformation
原始配置中的TUN inbound:
```json
{
  "type": "tun",
  "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
  "interface_name": "utun9",
  ...
}
```

转换后:
```json
{
  "type": "tun", 
  "address": ["10.10.0.1/30", "fdfe:dcba:9877::1/126"],
  "interface_name": "utun199",
  ...
}
```

## Non-Functional Requirements

- **NF1**: 配置变更后需要重新连接才能生效
- **NF2**: 无效配置应显示错误提示
- **NF3**: 默认值应避开常见冲突（不使用172.19.0.1）

## Out of Scope

- 自动检测冲突并推荐配置
- 运行时动态切换TUN配置
- 自定义MTU、stack等高级选项（可后续扩展）

## Success Criteria

1. 用户可以在Settings中修改TUN配置
2. 修改后重新连接，sing-box使用新的TUN配置
3. 与其他代理工具不再冲突

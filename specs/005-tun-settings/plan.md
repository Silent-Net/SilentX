# Implementation Plan: TUN Interface Settings

## Phase 1: Data Model & Storage

### 1.1 Create TUNSettings Model

**File**: `SilentX/Models/TUNSettings.swift`

```swift
import Foundation

/// TUN interface configuration presets
enum TUNPreset: String, CaseIterable, Identifiable {
    case silentxDefault = "silentx_default"
    case alternativeA = "alternative_a"
    case alternativeB = "alternative_b"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .silentxDefault: return "SilentX 默认"
        case .alternativeA: return "备选方案 A"
        case .alternativeB: return "备选方案 B"
        case .custom: return "自定义"
        }
    }
    
    var interfaceName: String {
        switch self {
        case .silentxDefault: return "utun199"
        case .alternativeA: return "utun109"
        case .alternativeB: return "utun88"
        case .custom: return ""
        }
    }
    
    var ipv4Address: String {
        switch self {
        case .silentxDefault: return "10.10.0.1/30"
        case .alternativeA: return "172.20.0.1/30"
        case .alternativeB: return "192.168.199.1/30"
        case .custom: return ""
        }
    }
    
    var ipv6Address: String {
        switch self {
        case .silentxDefault: return "fdfe:dcba:9877::1/126"
        case .alternativeA: return "fdfe:dcba:9878::1/126"
        case .alternativeB: return "fdfe:dcba:9879::1/126"
        case .custom: return ""
        }
    }
}

/// TUN configuration settings
struct TUNSettings: Codable, Equatable {
    var preset: String = TUNPreset.silentxDefault.rawValue
    var interfaceName: String = "utun199"
    var ipv4Address: String = "10.10.0.1/30"
    var ipv6Address: String = "fdfe:dcba:9877::1/126"
    
    static let `default` = TUNSettings()
}
```

### 1.2 Add Storage Keys

**File**: `SilentX/Shared/Constants.swift` (add)

```swift
// TUN Settings Keys
static let tunSettingsKey = "tunSettings"
```

## Phase 2: Settings UI

### 2.1 Create TUNSettingsView

**File**: `SilentX/Views/Settings/TUNSettingsView.swift`

UI组件：
- Picker for preset selection
- TextField for interface name (disabled unless custom)
- TextField for IPv4 address (disabled unless custom)
- TextField for IPv6 address (disabled unless custom)
- Warning label when connected

### 2.2 Integrate into ProxyModeSettingsView

在现有的 `ProxyModeSettingsView.swift` 中添加 TUN Configuration section。

## Phase 3: Config Transformation

### 3.1 Modify ConnectionService

**File**: `SilentX/Services/ConnectionService.swift`

修改 `ensureMixedInbound()` 方法或创建新方法 `applyTUNSettings()`:

```swift
private func applyTUNSettings(_ configJSON: String) throws -> String {
    // 1. Load TUNSettings from UserDefaults
    // 2. Parse JSON
    // 3. Find TUN inbound
    // 4. Replace interface_name and address
    // 5. Return modified JSON
}
```

### 3.2 Update connect() Flow

```swift
func connect(profile: Profile) async throws {
    // ... existing code ...
    
    // Transform config
    var transformedConfig = try ensureMixedInbound(profile.configurationJSON)
    transformedConfig = try applyTUNSettings(transformedConfig)  // NEW
    
    try transformedConfig.write(to: configURL, atomically: true, encoding: .utf8)
    // ... rest of code ...
}
```

## Phase 4: Validation

### 4.1 Input Validation Helper

**File**: `SilentX/Services/TUNSettingsValidator.swift`

```swift
struct TUNSettingsValidator {
    static func validateInterfaceName(_ name: String) -> Bool {
        // Must match pattern: utun[0-999]
        let pattern = "^utun[0-9]{1,3}$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
    
    static func validateIPv4CIDR(_ cidr: String) -> Bool {
        // Validate private IP + CIDR notation
        // 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
    }
    
    static func validateIPv6CIDR(_ cidr: String) -> Bool {
        // Validate IPv6 + CIDR notation
    }
}
```

## File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `SilentX/Models/TUNSettings.swift` | Create | TUN配置数据模型 |
| `SilentX/Views/Settings/TUNSettingsView.swift` | Create | TUN设置UI |
| `SilentX/Views/Settings/ProxyModeSettingsView.swift` | Modify | 集成TUN设置section |
| `SilentX/Services/ConnectionService.swift` | Modify | 添加applyTUNSettings() |
| `SilentX/Services/TUNSettingsValidator.swift` | Create | 输入验证 |
| `SilentX/Shared/Constants.swift` | Modify | 添加存储key |

## Task Breakdown

### Phase 1: Data Model (2 tasks)
- [ ] T001: Create TUNSettings model and TUNPreset enum
- [ ] T002: Add storage key to Constants

### Phase 2: UI (3 tasks)
- [ ] T003: Create TUNSettingsView with preset picker
- [ ] T004: Add validation feedback UI
- [ ] T005: Integrate into ProxyModeSettingsView

### Phase 3: Config Transform (2 tasks)
- [ ] T006: Implement applyTUNSettings() in ConnectionService
- [ ] T007: Update connect() flow to apply TUN settings

### Phase 4: Validation (1 task)
- [ ] T008: Create TUNSettingsValidator

### Phase 5: Testing (2 tasks)
- [ ] T009: Test with different presets
- [ ] T010: Test custom configuration

## Estimated Effort

- Phase 1: 30 min
- Phase 2: 45 min
- Phase 3: 30 min
- Phase 4: 20 min
- Phase 5: 15 min
- **Total: ~2.5 hours**

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| 用户输入无效配置 | 严格的输入验证 + 默认回退 |
| 配置变更未生效 | 明确提示需要重连 |
| 与其他应用冲突检测 | Phase 2考虑，暂不实现 |

## Default Configuration Rationale

选择 `10.10.0.1/30` 和 `utun199` 作为默认值的原因：
1. **10.x.x.x** 段很少被家用路由器使用
2. **utun199** 编号较高，不太可能与系统或其他应用冲突
3. **IPv6** 使用不同的后缀 (9877) 区分

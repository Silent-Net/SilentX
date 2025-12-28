# UI Enhancement and Bug Fixes

## Problem Statement

The current SilentX UI has several issues that need to be addressed:

1. **Chinese Text Remnants**: Multiple views still contain Chinese text that should be English-only
2. **Dashboard Bloated**: The dashboard feels cluttered and lacks essential features like mode switching (Rule/Global/Direct) and system proxy controls
3. **Profiles Missing Features**: Users cannot rename profiles or edit configuration directly
4. **Nodes Page Ugly Icon**: The TLS lock icon looks out of place and should be removed
5. **Rules Page Layout Bug**: The "Final" badge is positioned incorrectly in the toolbar

---

## Proposed Changes

### Component 1: Remove All Chinese Text

#### [MODIFY] [GroupsView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Groups/GroupsView.swift)
- Replace all Chinese strings with English equivalents:
  - "选择一个代理组" → "Select a proxy group"
  - "请先连接代理" → "Please connect first"
  - "连接代理后即可查看和管理代理组" → "Connect to proxy to view and manage groups"
  - "正在加载代理组..." → "Loading proxy groups..."
  - "加载失败" → "Loading failed"
  - "重试" → "Retry"
  - "没有代理组" / "当前配置没有可用的代理组" → "No proxy groups available"

#### [MODIFY] [GroupDetailView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Groups/GroupDetailView.swift)
- Replace Chinese:
  - "节点" → "nodes"
  - "搜索节点" → "Search nodes"
  - "测速" → "Speed Test"
  - "测试所有节点延迟" → "Test all node latency"
  - "没有找到匹配的节点" → "No matching nodes found"

#### [MODIFY] [GroupListView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Groups/GroupListView.swift)
- Replace "刷新" → "Refresh"

#### [MODIFY] [OutboundGroup.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Models/OutboundGroup.swift)
- Replace "超时" → "Timeout"

#### [MODIFY] [LocalProcessEngine.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Services/Engines/LocalProcessEngine.swift)
- Replace all Chinese comments and error messages with English

---

### Component 2: Enhanced Dashboard

#### [MODIFY] [DashboardView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Dashboard/DashboardView.swift)
- Add mode switcher (Rule / Global / Direct) similar to SFM
- Add system proxy toggle (HTTP/SOCKS proxy status)
- Streamline layout for a cleaner, less cluttered appearance
- Remove redundant elements

#### [NEW] [ModeSwitcherView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Dashboard/ModeSwitcherView.swift)
- Segmented control for switching between Rule, Global, Direct modes
- Updates clash_mode in config when changed
- Visual indicator of current mode

#### [NEW] [SystemProxyControlView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Dashboard/SystemProxyControlView.swift)
- Toggle for enabling/disabling system HTTP/SOCKS proxy
- Shows current proxy status and ports
- Quick access to proxy settings

---

### Component 3: Profile Management Enhancements

#### [MODIFY] [ProfileListView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Profiles/ProfileListView.swift)
- Add "Rename" action to profile context menu
- Add "Edit Config" action to open config editor

#### [MODIFY] [ProfileRowView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Profiles/ProfileRowView.swift)
- Support inline renaming with text field

#### [NEW] [ProfileEditorView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Profiles/ProfileEditorView.swift)
- Simple JSON text editor for configuration
- Syntax highlighting for JSON (optional)
- Save and cancel buttons
- Validation before save

---

### Component 4: Nodes Page - Remove Lock Icon

#### [MODIFY] [NodeRowView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Nodes/NodeRowView.swift)
- Remove the TLS lock icon (`lock.fill`) from line 32
- The presence of TLS is already implied by protocol type

---

### Component 5: Rules Page - Fix Final Badge Position

#### [MODIFY] [ConfigRuleListView.swift](file:///Users/xmx/workspace/Silent-Net/SilentX/SilentX/Views/Rules/ConfigRuleListView.swift)
- Move "Final" badge from toolbar to a proper position within the content area
- Consider placing it at the end of the rules list as a special row
- Or embed it in the navigation title area

---

## Verification Plan

### Manual Verification
1. Search entire codebase for Chinese characters - should return 0 results
2. Check Dashboard displays mode switcher and system proxy controls
3. Verify profile rename and config editor work correctly
4. Confirm lock icon is removed from nodes page
5. Verify "Final" badge displays in correct position on rules page

### Visual Verification
- Dashboard should look cleaner and more streamlined
- Mode switcher should be prominent and easy to use
- Profile editor should be functional and user-friendly

---

## Priority

| Component | Priority | Complexity |
|-----------|----------|------------|
| Remove Chinese Text | P0 | Low |
| Fix Rules Final Badge | P0 | Low |
| Remove Lock Icon | P0 | Trivial |
| Enhanced Dashboard | P1 | Medium |
| Profile Management | P2 | Medium |

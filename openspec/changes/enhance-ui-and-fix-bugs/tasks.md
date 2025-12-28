# Tasks: UI Enhancement and Bug Fixes

## Phase 1: Quick Fixes (P0) ✅

### 1. Remove All Chinese Text
- [x] 1.1 Translate `GroupsView.swift` - 7 strings
- [x] 1.2 Translate `GroupDetailView.swift` - 5 strings
- [x] 1.3 Translate `GroupListView.swift` - 1 string
- [x] 1.4 Translate `OutboundGroup.swift` - 1 string  
- [x] 1.5 Translate `LocalProcessEngine.swift` - comments and errors
- [x] 1.6 Verify: `grep -rE '[\x{4e00}-\x{9fff}]' SilentX/` returns 0 results

### 2. Fix Rules Page Final Badge Position
- [x] 2.1 Move "Final" badge from toolbar to navigationSubtitle
- [x] 2.2 Now displays as "21 rules · Final: direct" in subtitle area
- [x] 2.3 Build verified

### 3. Remove Lock Icon from Nodes Page
- [x] 3.1 Remove `lock.fill` Image from `NodeRowView.swift`
- [x] 3.2 Build verified

---

## Phase 2: Dashboard Enhancement (P1) ✅

### 4. Add Mode Switcher
- [x] 4.1 Create `ModeSwitcherView.swift` with Rule/Global/Direct options
- [x] 4.2 Integrate mode switcher into DashboardView
- [x] 4.3 Implement mode change API via clash_mode (ClashAPIClient.setMode)
- [x] 4.4 Persist selected mode across sessions (@AppStorage)

### 5. Add System Proxy Controls
- [x] 5.1 Create `SystemProxyControlView.swift`
- [x] 5.2 Add HTTP proxy toggle (stub - needs networksetup integration)
- [x] 5.3 Display current proxy ports from config
- [x] 5.4 Added httpPort/socksPort properties to ConnectionService

### 6. Streamline Dashboard Layout
- [x] 6.1 Reduced visual clutter
- [x] 6.2 Improved spacing and layout hierarchy
- [x] 6.3 Mode switcher and proxy controls only visible when connected

---

## Phase 3: Profile Enhancements (P2) ✅

### 7. Profile Rename
- [x] 7.1 Add "Rename" to profile context menu
- [x] 7.2 Implement rename alert with TextField
- [x] 7.3 Save rename to Profile model

### 8. Profile Config Editor
- [x] 8.1 Create `ProfileEditorView.swift`
- [x] 8.2 Add TextEditor for JSON editing with monospace font
- [x] 8.3 Implement JSON validation (real-time)
- [x] 8.4 Add save/cancel actions with ⌘S shortcut
- [x] 8.5 Add "Edit Config" to profile context menu

---

## Verification ✅
- [x] All Chinese text removed
- [x] Dashboard mode switcher works
- [x] System proxy controls display (stub implementation)
- [x] Profile rename works
- [x] Profile editor saves correctly
- [x] Lock icon removed from nodes
- [x] Final badge displays correctly
- [x] Build succeeded

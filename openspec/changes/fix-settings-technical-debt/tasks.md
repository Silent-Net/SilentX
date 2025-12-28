# Implementation Tasks

## 1. System Extension Installation Fix
- [ ] 1.1 Inspect Xcode project for SilentX.System embed settings
- [ ] 1.2 Ensure "Embed & Sign" is set for system extension target
- [ ] 1.3 Verify extension lands in `SilentX.app/Contents/PlugIns/SilentX.System.systemextension/`

## 2. Proxy Mode - Profile Auto-Selection
- [x] 2.1 Add `@AppStorage("selectedProfileID")` to ProxyModeSettingsView
- [x] 2.2 Query SwiftData for profile matching stored ID
- [x] 2.3 Fall back to first profile if stored ID not found
- [x] 2.4 Update `selectedProfile` binding on view appear

## 3. General Settings - Button Implementations
- [x] 3.1 `Open Data Folder`: Call `NSWorkspace.shared.open(FilePath.applicationSupport)`
- [x] 3.2 `Reset All Settings`: 
  - Add confirmation alert
  - Remove all @AppStorage keys via UserDefaults
- [x] 3.3 `Launch at Login`: 
  - Import ServiceManagement
  - Use `SMAppService.mainApp.register()` / `unregister()`
- [ ] 3.4 Wire notification toggles to ConnectionService notification posting

## 4. General Settings - Behavior Wiring
- [x] 4.1 Auto-connect on launch: Check `autoConnectOnLaunch` in MainView.swift, trigger connect
- [x] 4.2 Reconnect on disconnect: In ConnectionService, check `autoReconnectOnDisconnect` and schedule reconnect

## 5. Appearance Settings - UI Wiring
- [x] 5.1 Apply `colorScheme` via `.preferredColorScheme()` modifier at app root
- [x] 5.2 Apply `accentColor` via `.tint()` modifier at app root
- [x] 5.3 Read `sidebarIconsOnly` in sidebar to toggle label visibility
- [ ] 5.4 Read `showConnectionStats` to toggle stats in sidebar
- [ ] 5.5 Read `dashboardStyle` in DashboardView for layout selection
- [ ] 5.6 Read `showSpeedGraph` to toggle speed graph visibility
- [ ] 5.7 Apply `logFontSize` and `logColorCoding` in LogView

## 6. Verification
- [x] 6.1 Build project and verify no compile errors
- [ ] 6.2 Test each General Settings button action
- [ ] 6.3 Test appearance changes reflect in UI
- [ ] 6.4 Test proxy mode profile auto-selection

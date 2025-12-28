# Change: Fix Settings Panel Technical Debt

## Why
The Settings panel has accumulated technical debt from earlier development phases. Many UI elements are stub implementations that don't perform their intended actions, leading to poor user experience.

## What Changes

### System Extension Installation (Bug Fix)
- Fix "Extension not found in App bundle" error
- Ensure SilentX.System is properly embedded in app bundle's PlugIns directory

### Proxy Mode Tab
- **Auto-select profile**: When no profile is bound, auto-select from available profiles using `selectedProfileID`
- Remove "Please select a profile first" placeholder when profiles exist

### General Tab - Implement Stub Buttons
- **Open Data Folder**: Open `~/Library/Application Support/Silent-Net.SilentX/` in Finder
- **Reset All Settings**: Clear all `@AppStorage` keys with confirmation
- **Launch at Login**: Wire to `SMAppService` for login item management
- **Notification toggles**: Wire to actual notification posting logic
- **Auto-connect on launch**: Implement in `SilentXApp.swift`
- **Reconnect on disconnect**: Implement in `ConnectionService`

### Appearance Tab - Wire Settings to UI
- **colorScheme**: Apply to app's `preferredColorScheme` modifier
- **accentColor**: Apply to app's `tint` modifier
- **sidebarIconsOnly**: Wire to sidebar label visibility
- **showConnectionStats**: Wire to sidebar stats display
- **dashboardStyle**: Wire to DashboardView layout
- **showSpeedGraph**: Wire to speed graph visibility
- **logFontSize/logColorCoding**: Wire to LogView

## Impact
- Affected files: `GeneralSettingsView.swift`, `AppearanceSettingsView.swift`, `ProxyModeSettingsView.swift`, `SilentXApp.swift`, `ConnectionService.swift`, `ContentView.swift`
- Breaking changes: None
- Data migration: None (uses existing @AppStorage keys)

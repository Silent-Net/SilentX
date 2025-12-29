# add-menu-bar-dock-settings

## Summary
Add menu bar icon support and option to hide SilentX from the Dock. This is a key differentiator from SFM - users who prefer a clean Dock can run SilentX as a menu bar-only app.

## Status
- [x] Proposal created
- [ ] Approved
- [ ] Implemented
- [ ] Deployed

## Current Behavior
- App only shows in Dock
- No menu bar icon
- `showInMenuBar` and `hideOnClose` settings exist in GeneralSettingsView but are not implemented

## Proposed Changes

### 1. Menu Bar Icon (MenuBarExtra)
Add a SwiftUI `MenuBarExtra` scene to `SilentXApp.swift`:
- Show connection status indicator
- Quick profile switching
- Connect/Disconnect toggle
- Open main window
- Quit button

### 2. Hide from Dock Setting
Add setting to hide app from Dock using `NSApp.setActivationPolicy`:
- `.regular` = Show in Dock (default)
- `.accessory` = Hide from Dock (menu bar only)

This uses the existing `showInMenuBar` setting that's already in GeneralSettingsView.

## Technical Approach

### Menu Bar Implementation
```swift
// In SilentXApp.swift body
MenuBarExtra("SilentX", systemImage: "globe.americas") {
    MenuBarView()
}
.menuBarExtraStyle(.menu)  // or .window for full panel
```

### Dock Hiding Implementation
```swift
// When user toggles "Hide from Dock" in settings
if hideFromDock {
    NSApp.setActivationPolicy(.accessory)
} else {
    NSApp.setActivationPolicy(.regular)
}
```

## Files to Modify/Add
- `SilentXApp.swift` - Add MenuBarExtra scene
- `Views/MenuBar/MenuBarView.swift` - [NEW] Menu bar dropdown content
- `Views/Settings/GeneralSettingsView.swift` - Add "Hide from Dock" toggle
- `Shared/AppDelegate.swift` or equivalent - Handle activation policy changes

## User Benefits
- Quick access from menu bar without opening main window
- Clean Dock for users who don't want apps cluttering it
- Similar UX to other macOS VPN/proxy apps (Surge, ClashX, etc.)

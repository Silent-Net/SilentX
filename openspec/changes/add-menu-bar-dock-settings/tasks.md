# Tasks

## Phase 1: Menu Bar Icon

- [ ] **1.1 Create MenuBarView**
  - Create `Views/MenuBar/MenuBarView.swift`
  - Show connection status (Connected/Disconnected)
  - Profile selector with radio buttons
  - Connect/Disconnect button
  - "Open SilentX" button
  - "Settings" button
  - Quit button

- [ ] **1.2 Add MenuBarExtra to SilentXApp**
  - Add `MenuBarExtra` scene to app body
  - Use system icon (e.g., `globe.americas` or custom)
  - Link to MenuBarView

- [ ] **1.3 Menu Bar Status Icon**
  - Dynamic icon based on connection status
  - Connected: filled icon
  - Disconnected: outline icon

## Phase 2: Dock Hiding

- [ ] **2.1 Add "Hide from Dock" setting**
  - Add toggle in GeneralSettingsView
  - Use `@AppStorage("hideFromDock")`
  - Show warning that menu bar must stay visible

- [ ] **2.2 Implement activation policy change**
  - Use `NSApp.setActivationPolicy(.accessory)` to hide from Dock
  - Use `NSApp.setActivationPolicy(.regular)` to show in Dock
  - Apply on app launch based on saved setting

- [ ] **2.3 Handle window visibility**
  - When hiding from Dock, ensure window can still be opened
  - Use `NSApp.activate(ignoringOtherApps:)` when opening from menu bar

## Phase 3: Verification

- [ ] **3.1 Test menu bar functionality**
  - Profile switching works
  - Connect/disconnect works
  - Status icon updates correctly

- [ ] **3.2 Test dock hiding**
  - App hides from Dock correctly
  - Can still open window from menu bar
  - Setting persists across launches

# Settings Panel Capability

## ADDED Requirements

### Requirement: General Settings Data Management
The system SHALL provide functional data management controls.

#### Scenario: Open Data Folder
- **WHEN** user clicks "Open Data Folder in Finder"
- **THEN** Finder opens `~/Library/Application Support/Silent-Net.SilentX/`

#### Scenario: Reset All Settings
- **WHEN** user clicks "Reset All Settings"
- **THEN** a confirmation dialog is shown
- **AND** upon confirmation, all @AppStorage keys are cleared
- **AND** app returns to default settings state

---

### Requirement: Launch at Login
The system SHALL support automatic launch at macOS login.

#### Scenario: Enable Launch at Login
- **WHEN** user enables "Launch at login" toggle
- **THEN** app registers as a login item via SMAppService
- **AND** toggle reflects enabled state

#### Scenario: Disable Launch at Login
- **WHEN** user disables "Launch at login" toggle
- **THEN** app unregisters as a login item
- **AND** toggle reflects disabled state

---

### Requirement: Appearance Theme Application
The system SHALL apply appearance settings to the UI.

#### Scenario: Color Scheme Change
- **WHEN** user selects System/Light/Dark color scheme
- **THEN** app window immediately reflects the selected appearance

#### Scenario: Accent Color Change
- **WHEN** user selects a different accent color
- **THEN** app tint color changes throughout the interface

---

### Requirement: Proxy Mode Profile Auto-Selection
The system SHALL auto-select a profile for proxy mode settings.

#### Scenario: Auto-Select Stored Profile
- **WHEN** Proxy Mode tab opens
- **AND** a profile ID is stored in settings
- **THEN** that profile is pre-selected in the picker

#### Scenario: Fall Back to First Profile
- **WHEN** Proxy Mode tab opens
- **AND** no profile ID is stored OR stored ID is invalid
- **AND** profiles exist in the database
- **THEN** the first available profile is selected

---

### Requirement: Auto-Connect on Launch
The system SHALL optionally connect automatically when launched.

#### Scenario: Auto-Connect Enabled
- **WHEN** app launches
- **AND** "Connect automatically on launch" is enabled
- **AND** a profile is selected
- **THEN** proxy connection starts automatically

---

### Requirement: Auto-Reconnect on Disconnect
The system SHALL optionally reconnect after unexpected disconnection.

#### Scenario: Reconnect After Disconnect
- **WHEN** proxy unexpectedly disconnects
- **AND** "Reconnect automatically on disconnect" is enabled
- **THEN** connection is retried after the configured delay

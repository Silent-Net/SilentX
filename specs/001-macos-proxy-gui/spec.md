# Feature Specification: SilentX - User-Friendly macOS Proxy Tool

**Feature Branch**: `001-macos-proxy-gui`  
**Created**: December 6, 2025  
**Status**: Draft  
**Input**: User description: "Based on the Sing-Box proxy core, create the most user-friendly macOS proxy tool with JSON configuration management, GUI for node/rule management, and core version management with auto-update"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect to Proxy Server (Priority: P1)

As a user, I want to launch SilentX, select an existing configuration profile, and connect to my proxy server with a single click so that I can start browsing securely immediately.

**Why this priority**: This is the core value proposition - users need to establish proxy connections. Without this, the application has no utility.

**Independent Test**: Can be fully tested by launching the app with a pre-configured profile and clicking the connect button, verifying network traffic routes through the proxy.

**Acceptance Scenarios**:

1. **Given** a user has a valid configuration profile loaded, **When** they click the "Connect" button, **Then** the proxy connection is established within 5 seconds and the connection status indicator turns green.
2. **Given** a user is connected to a proxy, **When** they click the "Disconnect" button, **Then** the proxy connection is terminated and all network traffic returns to direct routing.
3. **Given** a user launches the app for the first time, **When** no profiles exist, **Then** the app displays a welcome message guiding them to create or import a profile.

**MVP Note**: The MVP (Phases 1-10) delivers connection **simulation** with mock core. Real Sing-Box core integration and system proxy control are implemented in Post-MVP phases (11-12). This allows UI/UX validation before system-level integration complexity.

---

### User Story 2 - Import Configuration Profile (Priority: P1)

As a user, I want to import proxy configuration from a URL, local file, or subscription link so that I can quickly set up my proxy without manual configuration.

**Note**: Subscription auto-update (FR-003) is Post-MVP (Phase 13). MVP (Phase 4) delivers one-time import from URL/file only.

**Why this priority**: Users need a way to get configurations into the app before they can connect. This is essential for first-time setup.

**Independent Test**: Can be tested by importing a configuration file/URL and verifying the profile appears in the profile list with correct settings.

**Acceptance Scenarios**:

1. **Given** a user has a valid configuration URL, **When** they paste the URL and click "Import", **Then** the configuration is downloaded, validated, and saved as a new profile.
2. **Given** a user has a local JSON configuration file, **When** they drag and drop the file onto the app or use "Import from File", **Then** the configuration is validated and saved as a new profile.
3. **Given** an imported configuration is invalid, **When** validation fails, **Then** the app displays a clear error message indicating what is wrong and does not save the profile.
4. **Given** network is unavailable during URL import, **When** the download fails, **Then** the app displays a clear error message with retry guidance within 1 second and does not corrupt existing profiles.

---

### User Story 3 - Manage Proxy Nodes via GUI (Priority: P2)

As a user, I want to add, edit, and delete proxy nodes through a visual interface so that I can manage my servers without editing JSON manually.

**Why this priority**: This significantly improves usability for non-technical users and reduces configuration errors.

**Independent Test**: Can be tested by adding a new node through the GUI and verifying it appears in the configuration and can be used for connections.

**Acceptance Scenarios**:

1. **Given** a user wants to add a new proxy node, **When** they click "Add Node" and fill in the required fields (name, server address, port, protocol type), **Then** the node is added to the current profile.
2. **Given** a user wants to edit an existing node, **When** they select the node and modify its properties, **Then** the changes are saved and take effect on the next connection.
3. **Given** a user wants to delete a node, **When** they select the node and confirm deletion, **Then** the node is removed from the profile.

---

### User Story 4 - Manage Routing Rules via GUI (Priority: P2)

As a user, I want to create and manage routing rules through a visual interface so that I can control which traffic goes through the proxy without editing JSON directly.

**Why this priority**: Routing rules determine proxy behavior. A GUI makes this accessible to users who don't understand JSON syntax.

**Independent Test**: Can be tested by creating a routing rule through the GUI and verifying specific domains/apps route as configured.

**Acceptance Scenarios**:

1. **Given** a user wants to add a domain-based rule, **When** they specify a domain pattern and select "Proxy" or "Direct", **Then** traffic to matching domains follows the specified routing.
2. **Given** a user wants to create an application-based rule, **When** they select an application from their system, **Then** all traffic from that application follows the specified routing.
3. **Given** a user wants to reorder rule priorities, **When** they drag rules to new positions, **Then** the rule evaluation order is updated accordingly.

---

### User Story 5 - Manage Sing-Box Core Versions (Priority: P3)

As a user, I want to download, switch between, and auto-update different versions of the Sing-Box core so that I can use the most stable or latest features as needed.

**Why this priority**: Core version management provides flexibility for advanced users and ensures compatibility, but basic proxy functionality works with any bundled core.

**Independent Test**: Can be tested by downloading a different core version and switching to it, verifying the app operates with the new core.

**Acceptance Scenarios**:

1. **Given** a user wants to download a new core version, **When** they enter a version number or URL and click "Download", **Then** the core binary is downloaded and cached locally.
2. **Given** a user has multiple core versions cached, **When** they select a different version from the list, **Then** the app switches to using that core version after a restart.
3. **Given** auto-update is enabled, **When** a new stable core version is released, **Then** the app downloads it in the background and notifies the user.

---

### User Story 6 - Edit Raw JSON Configuration (Priority: P3)

As an advanced user, I want to directly edit the JSON configuration with syntax highlighting and validation so that I have full control over all Sing-Box settings.

**Why this priority**: Provides escape hatch for advanced configurations not covered by the GUI.

**Independent Test**: Can be tested by editing JSON directly and verifying changes are saved and applied correctly.

**Acceptance Scenarios**:

1. **Given** a user wants to edit raw configuration, **When** they open the JSON editor for a profile, **Then** the complete configuration is displayed with syntax highlighting.
2. **Given** a user makes changes to the JSON, **When** they save, **Then** the configuration is validated and saved if valid, or errors are shown if invalid.

---

### Edge Cases

- What happens when the network is unavailable during profile import? Display error message "Network unavailable. Check connection and retry." with Retry button, allow retry, timeout after 30s for URL imports (distinct from 5s connection establishment in SC-008 which measures proxy tunnel setup only).
- What happens when the Sing-Box core crashes? Detect crash via watchdog, restore system proxy settings immediately, log error with stack trace, update status to "Disconnected - Core Crashed", show recovery guidance: "Core process stopped unexpectedly. Check logs for details."
- What happens when a configuration URL returns invalid data? Validate JSON schema before saving, show specific parsing error (line/column if possible), do not corrupt existing profiles, preserve last working configuration.
- What happens when disk space is low during core download? Check available space before download (require 100MB minimum), abort with "Insufficient disk space. Free at least 100MB and retry."
- What happens when multiple core versions have the same version number? Use SHA256 hash-based deduplication, keep only one binary per hash, display hash suffix in UI if version numbers collide.

## Requirements *(mandatory)*

### Functional Requirements

#### Configuration Management
- **FR-001**: System MUST support importing configuration profiles from URLs (http/https).
- **FR-002**: System MUST support importing configuration profiles from local JSON files.
- **FR-003**: System MUST support subscription links with automatic profile updates.
- **FR-004**: System MUST validate JSON configurations against Sing-Box v1.9.x schema (https://sing-box.sagernet.org/configuration/) before saving. Validation checks: required fields (outbounds array, log object), protocol-specific fields per outbound type, and route structure.
- **FR-005**: System MUST persist all profiles locally between app sessions.
- **FR-006**: System MUST support multiple profiles with user-defined names.

#### Proxy Connection
- **FR-007**: System MUST start/stop the Sing-Box core process on user command.
- **FR-008**: System MUST display current connection status (connected/disconnected/connecting).
- **FR-009**: System MUST configure system proxy settings on macOS when connected. Sets HTTP proxy (port 2080) and HTTPS proxy (port 2080) via `networksetup` command. SOCKS5 proxy optional (port 1080). Backs up existing settings before modification.
- **FR-010**: System MUST restore original system proxy settings when disconnected. Restores HTTP/HTTPS/SOCKS5 settings from backup. If backup missing, disables all proxy settings.

#### Node Management GUI
- **FR-011**: System MUST provide a form-based interface for adding proxy nodes.
- **FR-012**: System MUST support common protocols (Shadowsocks, VMess, VLESS, Trojan, Hysteria2). VLESS uses same UUID-based auth as VMess but without AEAD encryption.
- **FR-013**: System MUST allow editing all node properties through the GUI.
- **FR-014**: System MUST allow deleting nodes with confirmation. If node is active in current connection, prompt "Disconnect before deleting active node" and block deletion.
- **FR-015**: System MUST display node latency/status when available. Latency measured via TCP handshake to node address (5s timeout). Refresh: on-demand (manual button) or periodic (60s interval when NodeListView visible). Display: <100ms green, 100-500ms yellow, >500ms red, timeout gray.

#### Rule Management GUI
- **FR-016**: System MUST provide interface for creating domain-based routing rules.
- **FR-017**: System MUST provide interface for creating IP-based routing rules.
- **FR-018**: System MUST provide interface for creating process/application-based routing rules.
- **FR-019**: System MUST allow drag-and-drop reordering of rules.
- **FR-020**: System MUST support rule actions: Proxy, Direct, Block.

#### Core Version Management
- **FR-021**: System MUST allow users to specify a URL to download Sing-Box core versions.
- **FR-022**: System MUST cache downloaded core versions locally.
- **FR-023**: System MUST allow switching between cached core versions. Switching requires app restart (prompt user). Active connection terminated gracefully before restart. Rollback to previous version if new core fails to start (automatic fallback within 10s).
- **FR-024**: System MUST support automatic checking for core updates.
- **FR-025**: System MUST display current core version information.

#### JSON Editor
- **FR-026**: System MUST provide a JSON editor with syntax highlighting.
- **FR-027**: System MUST validate JSON syntax in real-time.
- **FR-028**: System MUST validate configuration against Sing-Box schema on save.

#### Observability & Logging
- **FR-029**: System MUST provide a built-in log viewer with real-time log streaming.
- **FR-030**: System MUST support log severity filtering (error/warning/info/debug levels).
- **FR-031**: System MUST allow exporting logs to file for troubleshooting.

### Key Entities

- **Profile**: Represents a complete proxy configuration; includes name, configuration content, source (local/remote), auto-update settings, and last-updated timestamp.
- **Node**: Represents a single proxy server within a profile; includes server address, port, protocol type, and protocol-specific credentials.
- **Rule**: Represents a routing rule; includes match criteria (domain/IP/process), action (proxy/direct/block), and priority order.
- **CoreVersion**: Represents a cached Sing-Box core binary; includes version number, download source, file path, and download date.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can import a configuration and establish a proxy connection in under 2 minutes from first app launch.
- **SC-002**: Users can add a new proxy node through the GUI in under 1 minute without consulting documentation.
- **SC-003**: Users can create a basic routing rule in under 30 seconds using the visual interface.
- **SC-004**: Configuration validation errors are displayed within 1 second of saving.
- **SC-005**: Core version switching completes within 10 seconds (excluding download time).
- **SC-006**: 95% of user configuration tasks can be completed through the GUI without editing raw JSON.
- **SC-007**: App launches and is ready to use within 3 seconds on standard hardware.
- **SC-008**: Proxy connection establishment completes within 5 seconds under normal network conditions.

## Clarifications

### Session 2025-12-06

- Q: How should SilentX integrate with the Sing-Box core? → A: Network Extension (VPN Mode) - Use macOS Network Extension framework like SFM does. Captures all system traffic, requires Apple Developer account with System Extension entitlements.
- Q: What level of logging and diagnostics should SilentX provide? → A: Built-in Log Viewer with real-time log streaming, severity filtering (error/warning/info/debug), and export capability.
- Q: What UI architecture pattern should SilentX follow? → A: NavigationSplitView (Sidebar) - macOS-native sidebar navigation like Finder/Mail. Left sidebar for sections, main content area on right. Standard macOS pattern.
- Q: What should be the MVP milestone scope? → A: GUI-First MVP - App structure + GUI for adding nodes + basic profile management + connect/disconnect. Focus on SwiftUI learning first, delay Sing-Box integration until UI foundation is solid.
- Q: How should profile and configuration data be persisted locally? → A: SwiftData - Apple's modern persistence framework with native SwiftUI integration and automatic iCloud sync capability.

## Assumptions

- Users have macOS 14.0 (Sonoma) or later installed (required for SwiftData).
- Users have administrative privileges to configure system proxy settings.
- The bundled default Sing-Box core version is compatible with the app at release.
- Network access is available for downloading remote configurations and core updates.
- Sing-Box configuration format follows the official JSON schema documentation.
- Development requires Apple Developer account with Network Extension entitlements for System Extension distribution.
- Data persistence uses SwiftData framework for native SwiftUI integration (local storage only, no iCloud sync in MVP).

# SilentX Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-12-13

## Active Technologies

- Swift 5.0 (with modern concurrency, async/await) + SwiftUI, SwiftData, Combine, NetworkExtension.framework, Libbox (sing-box Go library) (002-sudo-proxy-refactor)
- Privileged Helper Service (LaunchDaemon) for passwordless proxy management (003-privileged-helper)

## Project Structure

```text
SilentX/                        # Main application
  Services/
    Engines/                    # Proxy engine implementations
      LocalProcessEngine.swift  # sudo-based (password each time)
      PrivilegedHelperEngine.swift # Uses helper service (passwordless)
      NetworkExtensionEngine.swift # System VPN extension
    IPCClient.swift             # Unix socket client for helper service
    ServiceInstaller.swift      # Install/uninstall helper service
    ConnectionService.swift     # Orchestrates engine selection
  Views/Settings/
    ProxyModeSettingsView.swift # Engine selection and service management UI
    ServiceStatusView.swift     # Service status indicator
SilentX-Service/                # Privileged helper service (LaunchDaemon)
  main.swift                    # Entry point with signal handling
  IPCServer.swift               # Unix socket server
  CoreManager.swift             # sing-box process lifecycle
Resources/
  launchd.plist.template        # LaunchDaemon configuration
  install-service.sh            # Installation script
  uninstall-service.sh          # Uninstallation script
```

## Privileged Helper Architecture (003-privileged-helper)

### Overview
Enables passwordless proxy management like Clash Verge Rev:
- One-time admin password for service installation
- Service runs as LaunchDaemon with root privileges
- App communicates via Unix socket IPC
- No password required for connect/disconnect

### Key Components
1. **SilentX-Service**: Command-line daemon that:
   - Listens on `/tmp/silentx/silentx-service.sock`
   - Starts/stops sing-box with root privileges
   - Monitors process health and crash detection

2. **IPCClient**: Main app component that:
   - Sends JSON commands over Unix socket
   - Implements ping, version, start, stop, status
   - Handles timeouts and reconnection

3. **PrivilegedHelperEngine**: ProxyEngine implementation that:
   - Uses IPCClient for all operations
   - Polls service status every 2s when connected
   - Syncs state on app launch (T073)

### IPC Protocol
Line-based JSON over Unix socket:
```json
// Request
{"command": "start", "config_path": "/path/to/config.json", "core_path": "/path/to/sing-box"}

// Response  
{"success": true, "data": {"pid": 12345}}
```

### Service Lifecycle
1. Install: `osascript` prompts for admin → runs install-service.sh → launchctl loads plist
2. Connect: App sends `start` command → service launches sing-box
3. Disconnect: App sends `stop` command → service terminates sing-box
4. Uninstall: `osascript` prompts for admin → runs uninstall-service.sh

### File Locations
- Plist: `/Library/LaunchDaemons/com.silentnet.silentx.service.plist`
- Binary: `/Library/PrivilegedHelperTools/com.silentnet.silentx.service/silentx-service`
- Socket: `/tmp/silentx/silentx-service.sock`

## Commands

### Build Main App
```bash
xcodebuild -scheme SilentX -configuration Debug -destination 'platform=macOS' build
```

### Build Service (requires Xcode target setup)
```bash
xcodebuild -scheme SilentX-Service -configuration Release build
```

### Run Tests
```bash
xcodebuild test -scheme SilentX -destination 'platform=macOS'
```

## Code Style

Swift 5.0 (with modern concurrency, async/await): Follow standard conventions
- Use `@MainActor` for UI-bound classes
- Use `actor` for thread-safe state management
- Prefer async/await over completion handlers
- Use OSLog for logging with subsystem "com.silentnet.silentx"

## Recent Changes

- 002-sudo-proxy-refactor: Added Swift 5.0 (with modern concurrency, async/await) + SwiftUI, SwiftData, Combine, NetworkExtension.framework, Libbox (sing-box Go library)
- 003-privileged-helper: Added PrivilegedHelperEngine, IPCClient, ServiceInstaller, SilentX-Service daemon

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

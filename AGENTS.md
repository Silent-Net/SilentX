# AGENTS.md

A guide for AI coding agents working on **SilentX** — a macOS SwiftUI app that manages sing-box proxy connections with engine-based architecture.

## Project Overview

macOS native proxy client built with **Swift 5.0** (modern concurrency, async/await) + **SwiftUI**, **SwiftData**, **Combine**. Uses `NetworkExtension.framework` and **Libbox** (sing-box Go library) for proxy functionality.

### Architecture

- **Engine-based design**: `ProxyEngine` protocol with multiple implementations
  - `LocalProcessEngine`: sudo subprocess (password each time)
  - `PrivilegedHelperEngine`: LaunchDaemon service (passwordless after install)
  - `NetworkExtensionEngine`: System VPN extension (planned)
- **IPC via Unix socket**: JSON protocol over `/tmp/silentx/silentx-service.sock`
- **Reference implementation**: See `RefRepo/sing-box-for-apple` for NE/Libbox patterns

### Key Directories

```text
SilentX/                        # Main application
  Services/
    Engines/                    # ProxyEngine implementations
    IPCClient.swift             # Unix socket client
    ServiceInstaller.swift      # Helper service management
    ConnectionService.swift     # Engine orchestration
  Views/Settings/
    ProxyModeSettingsView.swift # Engine selection UI
SilentX-Service/                # Privileged helper daemon
  main.swift                    # Entry point with signal handling
  IPCServer.swift               # Unix socket server
  CoreManager.swift             # sing-box process lifecycle
SilentXTests/                   # Test suites
  EngineTests/                  # Engine-specific tests
```

## Setup Commands

```bash
# Build main app
xcodebuild -scheme SilentX -configuration Debug -destination 'platform=macOS' build

# Build privileged service (requires Xcode target)
xcodebuild -scheme SilentX-Service -configuration Release build

# Run tests
xcodebuild test -scheme SilentX -destination 'platform=macOS'
```

## File Locations

| Purpose | Path |
|---------|------|
| App support | `~/Library/Application Support/Silent-Net.SilentX/` |
| Profiles | `~/Library/Application Support/Silent-Net.SilentX/profiles/` |
| Core binaries | `~/Library/Application Support/Silent-Net.SilentX/cores/` |
| LaunchDaemon plist | `/Library/LaunchDaemons/com.silentnet.silentx.service.plist` |
| Helper binary | `/Library/PrivilegedHelperTools/com.silentnet.silentx.service/silentx-service` |
| IPC socket | `/tmp/silentx/silentx-service.sock` |
| Privileged log | `/tmp/singbox-privileged.log` |
| PID file | `/tmp/singbox-privileged.pid` |

## Code Style

### Swift Conventions
- Use `@MainActor` for UI-bound classes
- Use `actor` for thread-safe state management
- Prefer `async/await` over completion handlers
- Use `OSLog` with subsystem `"com.silentnet.silentx"`

### Engine Patterns
- Engines must publish status via Combine (`statusSubject`) and stay `@MainActor` for UI updates
- Validate config before launch (`configurationService.validate`)
- Extract ports and check availability before starting
- Error messages must be user-friendly (see `ProxyError`) and surfaced to UI; include log tail on failure
- Keep engines swappable: `ConnectionService` should not hardwire specific engines

### IPC Protocol
Line-based JSON over Unix socket:
```json
// Request
{"command": "start", "config_path": "/path/to/config.json", "core_path": "/path/to/sing-box"}

// Response
{"success": true, "data": {"pid": 12345}}
```

## Testing Instructions

- Run all tests: `xcodebuild test -scheme SilentX -destination 'platform=macOS'`
- Engine tests are in `SilentXTests/EngineTests/`
- When adding features, add minimal XCTest covering start/stop/error surfacing
- After every code change, confirm xcodebuild succeeds before committing

## Development Guidelines

### Service Lifecycle
1. **Install**: `osascript` prompts for admin → runs `install-service.sh` → `launchctl` loads plist
2. **Connect**: App sends `start` command → service launches sing-box
3. **Disconnect**: App sends `stop` command → service terminates sing-box
4. **Uninstall**: `osascript` prompts for admin → runs `uninstall-service.sh`

### Integration Notes
- sing-box binary is external (not in repo); ensure execute permissions and no quarantine before launch
- Rule-set downloads happen at startup; keep working directory at config directory
- AppleScript sudo prompts every run in LocalProcessEngine; avoid baking in password caching

### Debug Files
- `/tmp/singbox-privileged.log` — privileged launch logs
- `/tmp/singbox-privileged.pid` — process ID tracking
- Configs: `~/Library/Application Support/Silent-Net.SilentX/profiles/`

## Feature Specs

Feature specifications and plans live in `specs/` directory:
- `specs/002-sudo-proxy-refactor/` — current engine architecture
- `specs/003-privileged-helper/` — passwordless proxy management

Tasks are tracked in `specs/<feature>/tasks.md` and gate all work.

## PR Instructions

- Run `xcodebuild build` and `xcodebuild test` before committing
- Ensure all engine changes maintain the swappable architecture
- Update relevant task files when completing work

---

*Last updated: 2025-12-21*

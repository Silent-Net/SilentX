# Copilot Instructions for SilentX

## Big Picture
- macOS SwiftUI app that launches sing-box locally; architecture is engine-based (`ProxyEngine` protocol) with LocalProcessEngine (sudo subprocess) now and NetworkExtensionEngine planned later.
- Feature specs/plans live in [specs/002-sudo-proxy-refactor](../specs/002-sudo-proxy-refactor); tasks in [specs/002-sudo-proxy-refactor/tasks.md](../specs/002-sudo-proxy-refactor/tasks.md) gate work.
- Config, binaries, and runtime files live under `~/Library/Application Support/Silent-Net.SilentX/` (profiles, cores/, logs); privileged run log is `/tmp/singbox-privileged.log`, pid file `/tmp/singbox-privileged.pid`.
- Reference implementation for Network Extension / helper patterns is in sibling repo [RefRepo/sing-box-for-apple](../../RefRepo/sing-box-for-apple).

## Key Code Paths
- Engine abstraction: [SilentX/Services/Engines](../SilentX/Services/Engines) (`ProxyEngine`, `ProxyConfiguration`, `ProxyError`, `ConnectionStatus`).
- Local sudo flow: [SilentX/Services/Engines/LocalProcessEngine.swift](../SilentX/Services/Engines/LocalProcessEngine.swift) — AppleScript prompts for admin, writes pid to `/tmp/singbox-privileged.pid`, logs to `/tmp/singbox-privileged.log`; monitors ports and process.
- Connection orchestration: [SilentX/Services/ConnectionService.swift](../SilentX/Services/ConnectionService.swift) wires UI to engines.
- UI surfaces errors in [SilentX/Views/Dashboard](../SilentX/Views/Dashboard).
- Tests skeletons live in [SilentXTests](../SilentXTests); EngineTests folder exists/placeholder.

## Workflows
- Build (macOS): `xcodebuild -scheme SilentX -configuration Debug -destination 'platform=macOS' build` from repo root.
- After every code change you propose, run the above xcodebuild command and confirm it succeeds before handing changes back.
- Common debug files: `/tmp/singbox-privileged.log`, `/tmp/singbox-privileged.pid`; configs under `~/Library/Application Support/Silent-Net.SilentX/profiles/` and cores under `~/Library/Application Support/Silent-Net.SilentX/cores/`.
- When changing privileged launch, ensure password prompt behavior matches spec and capture PID/logs for error surfacing.

## Patterns & Conventions
- Engines must publish status via Combine (`statusSubject`) and stay @MainActor for UI updates.
- Validate config before launch (`configurationService.validate`); extract ports and check availability before starting.
- Error messages must be user-friendly (see `ProxyError`) and surfaced to UI; include log tail on failure.
- Keep engine swappable: ConnectionService should not hardwire LocalProcessEngine; NE path is reserved for future.
- AppleScript sudo prompts every run; long-term plan is helper/NE (see constitution/spec) — avoid baking in password caching.

## Integration Notes
- sing-box binary is external (not in repo); ensure execute permissions and no quarantine before launch.
- Rule-set downloads happen at startup; keep working directory at config directory to find rule assets.
- RefRepo/sing-box-for-apple shows NE/Libbox usage if implementing TUN/helper later.

## Testing Expectations
- T024/Engine tests pending; when adding features, add minimal XCTest covering start/stop/error surfacing in `SilentXTests/EngineTests` and run via Xcode or `xcodebuild test`.

Feedback welcome: flag unclear sections or missing rituals (build, test, run) and I’ll amend quickly.

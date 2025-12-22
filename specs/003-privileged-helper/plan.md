# Implementation Plan: Privileged Helper Service (LaunchDaemon + IPC)

**Branch**: `003-privileged-helper` | **Date**: 2025-12-14 | **Spec**: specs/003-privileged-helper/spec.md
**Input**: Feature specification from `specs/003-privileged-helper/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Ship a root-running `silentx-service` (LaunchDaemon) that starts/stops sing-box without repeated password prompts, exposes a local Unix-socket IPC API for the main app, and surfaces actionable errors (including underlying sing-box stdout/stderr).

Current debug signal (Dec 2025): The service can start sing-box successfully, but user traffic (e.g. YouTube) still fails in configs where `inbounds[0].type=tun` and `auto_route=false`. On Apple platforms, `tun.platform.http_proxy` is a client-side hint to apply system proxy; without applying system proxy or enabling `auto_route`, TUN alone will not capture traffic.

## Technical Context

This plan assumes SilentX is a macOS SwiftUI app that can bundle and install a root-running LaunchDaemon (`silentx-service`) for passwordless runtime operations.

**Language/Version**: Swift 5.x (Xcode toolchain)  
**Primary Dependencies**: SwiftUI, Combine, SwiftData, OSLog, Foundation, (service-side) POSIX/Network  
**Storage**: Files under `~/Library/Application Support/Silent-Net.SilentX/` + SwiftData for versions/profiles  
**Testing**: XCTest (unit) + XCUITest (flows)  
**Target Platform**: macOS (desktop app + bundled helper tool and optional NetworkExtension target)
**Project Type**: macOS app with auxiliary service target  
**Performance Goals**: Connect within 2s (SC-002), IPC p95 < 100ms (SC-006)  
**Constraints**: One-time admin prompt for install only; no password caching; deterministic working directory; clean teardown (no orphan processes, no stuck TUN/proxy settings)  
**Scale/Scope**: Single-user local daemon; low concurrency; reliability > throughput

**NEEDS CLARIFICATION (resolved in research.md)**:
- When sing-box config uses `tun` with `auto_route=false`, what must the client do for system traffic to flow?
- How to keep runtime config separation without breaking relative assets (e.g. `experimental.clash_api.external_ui = "ui"`, rule sets)?
- Best place to apply macOS system proxy settings (main app vs root service) to remain passwordless and reversible.

## Routing Responsibility Decision

**Default stance: System proxy mode when the config requests it.**

- If config contains `tun` and `auto_route=false` and `tun.platform.http_proxy.enabled=true`, SilentX treats this as an explicit client-side instruction and **enables macOS System HTTP/HTTPS proxy** to `127.0.0.1:<port>`.
- The proxy changes are performed by the LaunchDaemon service so runtime remains passwordless and reversible.
- If `tun.auto_route=true`, SilentX **does not** modify system proxy settings.
- If config is tun-only with `auto_route=false` and lacks a proxy hint, SilentX surfaces a clear actionable error instead of claiming “connected”.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

1. **User Consent & Least Privilege**
  - Install/uninstall uses macOS-standard authorization UI (AppleScript prompt) exactly once per operation.
  - Runtime operations are passwordless via LaunchDaemon.

2. **Deterministic Repro & Tests**
  - Must include reproducible steps for install/connect/disconnect and automated tests for: IPC happy-path, start/stop, and error surfacing.

3. **Explicit Error Transparency**
  - All startup failures must surface actionable messages in UI and include underlying sing-box stderr/stdout when available.

4. **Modular Engines**
  - Main app continues to select engines behind `ProxyEngine` (PrivilegedHelperEngine / LocalProcessEngine / NetworkExtensionEngine).

Status: PASS (no violations required), but Phase 1 must explicitly design proxy routing responsibility for configs with `tun.auto_route=false`.

## Project Structure

### Documentation (this feature)

```text
specs/003-privileged-helper/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
SilentX/
├── SilentX/                    # Main macOS app
│   ├── Services/               # ConnectionService, engines, proxy/system helpers
│   ├── Views/                  # Dashboard/Settings UI
│   └── Shared/
├── SilentX-Service/            # Privileged helper tool target (silentx-service)
├── SilentX-Extension/          # NetworkExtension target (optional engine)
└── SilentXTests/               # XCTest
```

**Structure Decision**: macOS app + helper tool target. IPC contract and installer scripts live under the main app bundle and/or service target resources, with documentation in `specs/003-privileged-helper/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

No constitution violations are required for this feature.

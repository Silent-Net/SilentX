# Implementation Plan: Sudo Proxy Refactor - 代理方案重构

**Branch**: `002-sudo-proxy-refactor` | **Date**: 2025-12-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-sudo-proxy-refactor/spec.md`

## Summary

重构 SilentX 代理方案。首要目标是用 macOS 标准授权（AuthorizationServices）获得管理员权限运行 sing-box（sudo/受控 helper），修复 “Core process exited during startup”。保持 ProxyEngine 抽象，优先交付本地进程引擎，Network Extension 保持可选/后续。

**关键决定**: 当前迭代以 sudo/授权 helper 方式启动 sing-box；Network Extension 作为后续可选模式，不影响当前 MVP。

## Technical Context

**Language/Version**: Swift 5.0 (with modern concurrency, async/await)
**Primary Dependencies**: SwiftUI, SwiftData, Combine, AuthorizationServices, Process API; NetworkExtension.framework reserved for later (optional), Libbox (sing-box Go library)
**Storage**: SwiftData + JSON files (`~/Library/Application Support/Silent-Net.SilentX/`)
**Testing**: XCTest (unit + UI tests)
**Target Platform**: macOS 12.0+ (Monterey and later)
**Project Type**: Single macOS application + System Extension
**Performance Goals**: Proxy startup in <5s, UI state update <2s on errors
**Constraints**: Requires user password via AuthorizationServices for sudo/helper path; System Extension approval only if/when NE mode is enabled
**Scale/Scope**: Single-user desktop application

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

> Constitution is not yet configured for this project (template placeholders present).
> Proceeding with standard best practices.

**Default Gates Applied:**
- [x] Single project structure (not unnecessarily split) - Main app + System Extension is Apple-required pattern
- [x] Testable design (protocol-based abstractions) - ProxyEngine protocol
- [x] Clear separation of concerns (Engine abstraction)
- [x] Security review required - Network Extension is Apple-sanctioned approach

**Post-Design Re-check:**
- [x] Data model is minimal and focused
- [x] Protocol contract is well-defined and testable
- [x] Implementation phases are incremental

## Project Structure

### Documentation (this feature)

```text
specs/002-sudo-proxy-refactor/
├── plan.md              # This file
├── research.md          # Phase 0 output - technology research ✅
├── data-model.md        # Phase 1 output - entity design ✅
├── quickstart.md        # Phase 1 output - implementation guide ✅
├── contracts/           # Phase 1 output - API contracts ✅
│   └── proxy-engine.md  # ProxyEngine protocol definition
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
SilentX/
├── Models/              # SwiftData models (existing)
│   ├── Profile.swift    # Add preferredEngine field
│   ├── ProxyNode.swift
│   ├── RoutingRule.swift
│   └── CoreVersion.swift
├── Services/            # Business logic
│   ├── ConnectionService.swift      # → Refactor to use ProxyEngine
│   ├── Engines/                      # NEW: Proxy engine implementations
│   │   ├── ProxyEngine.swift         # Protocol + types
│   │   ├── ProxyError.swift          # Error enum
│   │   ├── ProxyConfiguration.swift  # Config model
│   │   ├── LocalProcessEngine.swift  # HTTP/SOCKS proxy (no TUN)
│   │   └── NetworkExtensionEngine.swift  # TUN via System Extension
│   ├── SystemProxyService.swift
│   ├── ConfigurationService.swift
│   └── ... (other existing services)
├── Views/               # SwiftUI views (existing)
├── Shared/              # Constants, utilities (existing)
└── SilentX.entitlements # Update for Network Extension

SilentX.System/          # NEW: System Extension target
├── PacketTunnelProvider.swift
├── Info.plist
└── SilentX.System.entitlements

SilentXTests/
├── EngineTests/         # NEW: Tests for proxy engines
│   ├── LocalProcessEngineTests.swift
│   ├── ProxyEngineContractTests.swift
│   └── MockProxyEngine.swift
└── ... (existing tests)
```

**Structure Decision**: Extends现有单项目结构。新增 `Engines/` 目录用于 ProxyEngine 抽象。System Extension 目标为可选（启用 NE 时再添加）；当前聚焦本地进程+授权 helper 路径。

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
|----------|------------|-------------------------------------|
| System Extension target | Required by Apple for TUN mode | Direct process launch cannot create TUN without root |
| ProxyEngine protocol | Enable testing + future extensibility | Direct implementation would duplicate code between modes |

---

## Phase 0: Research ✅ Complete

See [research.md](research.md) for full findings.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Privilege escalation | Network Extension (not sudo) | SFM uses NE, Apple-sanctioned, App Store compatible |
| TUN implementation | NEPacketTunnelProvider | Only way to get TUN without root |
| Architecture | ProxyEngine protocol | Enables testing, mode switching |
| Implementation order | LocalProcess first, NE second | Fix current bugs before adding complexity |

---

## Phase 1: Design ✅ Complete

### Generated Artifacts

| Artifact | Path | Description |
|----------|------|-------------|
| Data Model | [data-model.md](data-model.md) | Entity definitions for ProxyEngine, ConnectionStatus, ProxyError |
| Protocol Contract | [contracts/proxy-engine.md](contracts/proxy-engine.md) | ProxyEngine protocol specification |
| Quickstart Guide | [quickstart.md](quickstart.md) | Step-by-step implementation instructions |

### Entity Summary

- **ProxyEngine** - Protocol for proxy implementations
- **LocalProcessEngine** - HTTP/SOCKS via direct process launch
- **NetworkExtensionEngine** - TUN via System Extension
- **ConnectionStatus** - Enum with disconnected/connecting/connected/error states
- **ProxyError** - Categorized errors with user-friendly messages
- **ProxyConfiguration** - Config passed to engine for startup

---

## Phase 2: Implementation (Next Step)

Run `/speckit.tasks` to generate implementation tasks based on this plan.

### Implementation Phases

**Phase 1 (P1 - Core Fix, Sudo-first)**:
1. Create ProxyEngine protocol and types
2. Implement LocalProcessEngine with AuthorizationServices password prompt + privileged launch
3. Debug and fix "Core process exited during startup" error
4. Refactor ConnectionService to use engine
5. Add unit tests (startup success, error surfacing, teardown)

**Phase 2 (P2 - Optional TUN/NE Mode)**:
1. (Optional) Create System Extension target
2. (Optional) Integrate Libbox (sing-box Go library)
3. (Optional) Implement PacketTunnelProvider
4. (Optional) Implement NetworkExtensionEngine
5. (Optional) Add extension approval flow in UI

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| LocalProcess debug takes longer than expected | Medium | Medium | Focus on logging, test with known-good config |
| Libbox integration complexity | High | High | Follow SFM's approach closely |
| System Extension approval UX confusing | Medium | Low | Add clear in-app guidance |
| App Store rejection for NE | Low | High | Ensure proper entitlements, follow Apple guidelines |

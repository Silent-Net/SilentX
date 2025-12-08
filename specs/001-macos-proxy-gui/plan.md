# Implementation Plan: SilentX - User-Friendly macOS Proxy Tool

**Branch**: `001-macos-proxy-gui` | **Date**: 2025-12-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-macos-proxy-gui/spec.md`

## Summary

Build a user-friendly macOS proxy tool using Sing-Box core with comprehensive GUI for profile management, node/rule configuration, and core version management with GitHub API integration. Focus on SwiftUI/SwiftData-first approach with test-driven development.

## Technical Context

**Language/Version**: Swift 5.9, macOS 14.0+ (Sonoma)
**Primary Dependencies**: SwiftUI (UI framework), SwiftData (persistence), Foundation (URLSession for networking), CryptoKit (SHA256 verification)
**Storage**: SwiftData (local database), Application Support directory (core binaries at `~/Library/Application Support/Silent-Net.SilentX/cores/`)
**Testing**: XCTest (unit tests in SilentXTests/), XCUITest (UI tests in SilentXUITests/), SwiftUI Previews (rapid iteration)
**Target Platform**: macOS 14.0+ (Sonoma and later)
**Project Type**: Native macOS application (single project structure)
**Performance Goals**: 
  - App launch: <3 seconds
  - Proxy connection: <5 seconds
  - Configuration validation: <1 second
  - Core version switch: <10 seconds (excluding download)
**Constraints**: 
  - Offline-capable for core features (except initial profile import)
  - Minimum 100MB disk space for core downloads
  - System proxy configuration requires admin privileges
**Scale/Scope**: 
  - Single-user desktop application
  - ~150 Swift files across 6 modules
  - 208 tasks total (140 complete, 67% done)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Version**: v1.1.0 (ratified 2025-12-06)

### Gate Results

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Test-First Delivery | ✅ PASS | All user stories have test tasks (T009-T053); tests marked "write first, must fail initially" |
| II. Security & Privacy | ✅ PASS | SwiftData local storage, OSLog redaction policy (T006), no telemetry |
| III. Performance Targets | ⚠️ PARTIAL | Targets documented (launch <3s, connect <5s); XCTest assertions pending (T046-T047) |
| IV. Observability | ✅ PASS | LogService with OSLog, in-app viewer (FR-029-031), export capability |
| V. Simplicity | ✅ PASS | SwiftUI + SwiftData, protocol-based services, clear contracts in contracts/ directory |
| VI. Versioning | ✅ PASS | CoreVersion model with checksum, reversible switching (FR-021-025) |
| VII. CI/CD | ⚠️ PARTIAL | CI entrypoint exists (T004); pre-commit hooks and perf gates need completion |

**Overall**: 5/7 gates pass, 2 partial (71% compliance)

**Action Required**:
1. Complete T046-T047 (performance XCTest assertions)
2. Enforce performance thresholds in CI pipeline
3. Add pre-commit hooks for build validation

**Approved for continuation**: Yes (partial gates have remediation tasks)

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
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
├── SilentX/                      # Main app target
│   ├── SilentXApp.swift         # @main entry point
│   ├── ContentView.swift        # Root view
│   ├── Models/                   # SwiftData @Model classes
│   │   ├── Profile.swift
│   │   ├── ProxyNode.swift
│   │   ├── RoutingRule.swift
│   │   ├── CoreVersion.swift
│   │   └── [enums: ProfileType, ProxyProtocol, RuleMatchType, RuleAction]
│   ├── Services/                 # Business logic layer
│   │   ├── ConnectionService.swift
│   │   ├── ProfileService.swift
│   │   ├── NodeService.swift
│   │   ├── RuleService.swift
│   │   ├── CoreVersionService.swift
│   │   ├── GitHubReleaseService.swift  # GitHub API client
│   │   ├── ConfigurationService.swift
│   │   ├── SystemProxyService.swift
│   │   ├── LogService.swift
│   │   └── PerformanceMetrics.swift
│   ├── Views/                    # SwiftUI views organized by feature
│   │   ├── MainView.swift
│   │   ├── SidebarView.swift
│   │   ├── Dashboard/
│   │   ├── Profiles/
│   │   ├── Nodes/
│   │   ├── Rules/
│   │   ├── Logs/
│   │   ├── Settings/
│   │   └── Onboarding/
│   ├── Shared/                   # Shared utilities
│   │   ├── Constants.swift
│   │   ├── FilePath.swift
│   │   └── FeatureFlags.swift
│   └── Assets.xcassets/
├── SilentXTests/                 # Unit tests
│   ├── SystemProxyServiceTests.swift
│   ├── ConnectionServiceTests.swift
│   ├── ProfileServiceSubscriptionTests.swift
│   ├── NodeServiceLatencyTests.swift
│   ├── RuleServiceValidationTests.swift
│   ├── CoreVersionServiceTests.swift
│   └── ConfigurationServiceValidationTests.swift
├── SilentXUITests/               # UI automation tests
│   ├── ConnectFlowTests.swift
│   ├── ProfileListCrashTests.swift
│   ├── ImportProfileTests.swift
│   ├── NodeManagementTests.swift
│   ├── RuleManagementTests.swift
│   ├── CoreVersionUITests.swift
│   ├── JSONEditorTests.swift
│   ├── PerformanceMetricsTests.swift  # Performance assertions
│   └── Support/
│       └── TestHarness.swift
├── Shared/                       # Shared framework (future: Network Extension)
├── SilentXExtension/             # Network Extension (Post-MVP Phase 11)
└── .github/
    └── workflows/
        └── ci.yml                # CI pipeline
```

**Structure Decision**: Native macOS app using standard Xcode project structure. Main app logic in `SilentX/SilentX/` with Models-Services-Views separation. Tests organized by service/feature. Network Extension scaffolded but implementation deferred to Post-MVP.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations requiring justification.** All architectural decisions align with Constitution Section V (Simplicity and Clear Contracts):

- ✅ SwiftUI + SwiftData: Standard Apple frameworks, no custom abstraction
- ✅ Protocol-based services: Clear contracts without over-engineering
- ✅ Direct SwiftData access: No repository pattern needed for single-app scope
- ✅ URLSession: Native networking, no third-party HTTP wrapper

**Deferred Complexity** (Post-MVP):
- Network Extension: Required for VPN mode, deferred to Phase 11 after GUI validation
- System proxy integration: Requires admin privileges, added in Phase 11 with proper error handling

# Tasks: Sudo Proxy Refactor - 代理方案重构

**Input**: Design documents from `/specs/002-sudo-proxy-refactor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/proxy-engine.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- **Main App**: `SilentX/` at repository root
- **System Extension**: `SilentX.System/` (Phase 2)
- **Tests**: `SilentXTests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure and base types for ProxyEngine architecture

- [x] T001 Create Engines directory at `SilentX/Services/Engines/`
- [x] T002 [P] Create EngineType enum in `SilentX/Services/Engines/EngineType.swift`
- [x] T003 [P] Create ProxyError enum with user-friendly messages in `SilentX/Services/Engines/ProxyError.swift`
- [x] T004 [P] Create ConnectionStatus enum with associated values in `SilentX/Services/Engines/ConnectionStatus.swift`
- [x] T005 [P] Create ConnectionInfo struct in `SilentX/Services/Engines/ConnectionInfo.swift`
- [x] T006 Create ProxyConfiguration struct in `SilentX/Services/Engines/ProxyConfiguration.swift`
- [x] T007 Create ProxyEngine protocol in `SilentX/Services/Engines/ProxyEngine.swift`

**Checkpoint**: Base types ready - engine implementation can begin

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T008 Create MockProxyEngine for testing in `SilentXTests/EngineTests/MockProxyEngine.swift`
- [ ] T009 Add preferredEngine field to Profile model in `SilentX/Models/Profile.swift`
- [ ] T010 Create EngineTests directory at `SilentXTests/EngineTests/`
- [x] T056 Add AuthorizationServices password prompt flow with retry cap (3 attempts) wired into `ConnectionService` / `LocalProcessEngine`
- [x] T057 Implement privileged launch path for sing-box using authorized helper/`sudo` (sandbox-safe) in `SilentX/Services/Engines/LocalProcessEngine.swift`, including cleanup on failure

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - 一键连接代理 (Priority: P1) 🎯 MVP

**Goal**: User clicks Connect, proxy starts reliably (fixing "Core process exited during startup" error)

**Independent Test**: Click Connect button with valid profile → sing-box process starts → HTTP/SOCKS proxy works

### Implementation for User Story 1

- [x] T011 [US1] Implement LocalProcessEngine base class in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T012 [US1] Add process launching with improved error capture in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T013 [US1] Add port availability check before starting in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T014 [US1] Add process termination monitoring in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T015 [US1] Add graceful shutdown (SIGTERM → wait → SIGKILL) in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T016 [US1] Add stderr parsing for specific error messages in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T017 [US1] Implement validate(config:) method in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [x] T018 [US1] Refactor ConnectionService to use ProxyEngine protocol in `SilentX/Services/ConnectionService.swift`
- [x] T019 [US1] Update ConnectionService.connect() to create LocalProcessEngine in `SilentX/Services/ConnectionService.swift`
- [x] T020 [US1] Update ConnectionService.disconnect() to use engine.stop() in `SilentX/Services/ConnectionService.swift`
- [x] T021 [US1] Subscribe to engine.statusPublisher in ConnectionService in `SilentX/Services/ConnectionService.swift`
- [x] T022 [US1] Update Dashboard UI to show ProxyError messages in `SilentX/Views/Dashboard/ConnectionStatusView.swift`
- [x] T023 [US1] Add debug logging for sing-box startup in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [ ] T024 [US1] Test with known-good config.json to verify fix

**Checkpoint**: User Story 1 complete - Connect/Disconnect works reliably with HTTP/SOCKS proxy

---

## Phase 4: User Story 2 - 代理模式切换 (Priority: P2)

**Goal**: User can switch between LocalProcess and NetworkExtension modes in Settings

**Independent Test**: Change mode in Settings → next Connect uses selected engine

### Implementation for User Story 2

- [ ] T025 [US2] Create System Extension target `SilentX.System` in Xcode project
- [ ] T026 [US2] Configure System Extension entitlements in `SilentX.System/SilentX.System.entitlements`
- [ ] T027 [US2] Update main app entitlements for NetworkExtension in `SilentX/SilentX.entitlements`
- [ ] T028 [US2] Create PacketTunnelProvider stub in `SilentX.System/PacketTunnelProvider.swift`
- [ ] T029 [US2] Create Info.plist for System Extension in `SilentX.System/Info.plist`
- [ ] T030 [US2] Implement NetworkExtensionEngine base class in `SilentX/Services/Engines/NetworkExtensionEngine.swift`
- [ ] T031 [US2] Add NETunnelProviderManager loading in `SilentX/Services/Engines/NetworkExtensionEngine.swift`
- [ ] T032 [US2] Add extension approval status check in `SilentX/Services/Engines/NetworkExtensionEngine.swift`
- [ ] T033 [US2] Add config writing to shared container in `SilentX/Services/Engines/NetworkExtensionEngine.swift`
- [ ] T034 [US2] Implement start() via startVPNTunnel() in `SilentX/Services/Engines/NetworkExtensionEngine.swift`
- [ ] T035 [US2] Implement stop() via stopVPNTunnel() in `SilentX/Services/Engines/NetworkExtensionEngine.swift`
- [ ] T036 [US2] Create ProxyModeSettingsView for mode selection in `SilentX/Views/Settings/ProxyModeSettingsView.swift`
- [ ] T037 [US2] Add engine type picker (LocalProcess/NetworkExtension) in `SilentX/Views/Settings/ProxyModeSettingsView.swift`
- [ ] T038 [US2] Add warning when switching mode while connected in `SilentX/Views/Settings/ProxyModeSettingsView.swift`
- [ ] T039 [US2] Update ConnectionService to read preferredEngine from Profile in `SilentX/Services/ConnectionService.swift`
- [ ] T040 [US2] Update ConnectionService to create appropriate engine based on preference in `SilentX/Services/ConnectionService.swift`

**Checkpoint**: User Story 2 complete - Users can switch between LocalProcess and NetworkExtension modes

---

## Phase 5: User Story 3 - 连接状态监控 (Priority: P3)

**Goal**: User sees real-time status: mode, duration, errors with clear messages

**Independent Test**: Connect → Dashboard shows green status, mode, duration → Disconnect → shows gray

### Implementation for User Story 3

- [ ] T041 [P] [US3] Add formattedDuration computed property in `SilentX/Services/Engines/ConnectionInfo.swift`
- [ ] T042 [P] [US3] Add engineType display name (Chinese) in `SilentX/Services/Engines/EngineType.swift`
- [ ] T043 [US3] Update ConnectionStatusView to show engine type in `SilentX/Views/Dashboard/ConnectionStatusView.swift`
- [ ] T044 [US3] Update ConnectionStatusView to show connection duration in `SilentX/Views/Dashboard/ConnectionStatusView.swift`
- [ ] T045 [US3] Update ConnectionStatusView to show user-friendly error messages in `SilentX/Views/Dashboard/ConnectionStatusView.swift`
- [ ] T046 [US3] Add color-coded status indicator (green/red/gray) in `SilentX/Views/Dashboard/ConnectionStatusView.swift`
- [ ] T047 [US3] Add suggested action text for recoverable errors in `SilentX/Views/Dashboard/ConnectionStatusView.swift`
- [ ] T048 [US3] Add timer for live duration update in `SilentX/Views/Dashboard/ConnectionStatusView.swift`

**Checkpoint**: User Story 3 complete - Dashboard shows comprehensive status information

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T049 [P] Add logging throughout engine lifecycle in `SilentX/Services/Engines/`
- [ ] T050 [P] Create LocalProcessEngineTests in `SilentXTests/EngineTests/LocalProcessEngineTests.swift`
- [ ] T051 [P] Create ProxyEngineContractTests in `SilentXTests/EngineTests/ProxyEngineContractTests.swift`
- [ ] T052 Handle system sleep/wake events in ConnectionService in `SilentX/Services/ConnectionService.swift`
- [ ] T053 Add retry logic for transient errors in `SilentX/Services/Engines/LocalProcessEngine.swift`
- [ ] T054 Run quickstart.md validation scenarios
- [ ] T055 Update CLAUDE.md with new architecture notes

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) ← BLOCKS all user stories
    │
    ├──────────────────────────────────┐
    ▼                                  ▼
Phase 3 (US1: Connect) ─────────► Phase 4 (US2: Mode Switch)
    │                                  │
    └──────────────────────────────────┤
                                       ▼
                              Phase 5 (US3: Status)
                                       │
                                       ▼
                              Phase 6 (Polish)
```

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2 - No dependencies on other stories
- **User Story 2 (P2)**: Depends on US1 for ConnectionService refactoring
- **User Story 3 (P3)**: Can start after Phase 2 - Uses ConnectionStatus from US1

### Within Each User Story

- Types/Models before implementation
- Core implementation before UI updates
- Main functionality before error handling polish

### Parallel Opportunities

**Phase 1** (Setup):
```
T002, T003, T004, T005 can run in parallel (different files)
```

**Phase 3** (US1) - After T011:
```
T012-T017 are sequential (same file)
T018-T021 are sequential (same file)
T022 can run in parallel with T018-T021
```

**Phase 5** (US3):
```
T041, T042 can run in parallel
T043-T048 are sequential (same file)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T007)
2. Complete Phase 2: Foundational (T008-T010)
3. Complete Phase 3: User Story 1 (T011-T024)
4. **STOP and VALIDATE**: Test Connect/Disconnect with HTTP proxy
5. If working → MVP achieved, deploy for testing

### Incremental Delivery

1. Setup + Foundational → Base types ready
2. **US1 (P1)**: Connect works → Core value delivered
3. **US2 (P2)**: Mode switching → Advanced users can use NE
4. **US3 (P3)**: Status display → Better UX
5. Polish → Production ready

### Risk Mitigation

- **T024** is critical validation step - do not skip
- If LocalProcessEngine still fails, focus debugging before moving to US2
- NetworkExtension (US2) has highest complexity - can be deferred if needed

---

## Summary

| Metric | Count |
|--------|-------|
| Total Tasks | 55 |
| Phase 1 (Setup) | 7 |
| Phase 2 (Foundational) | 3 |
| Phase 3 (US1 - Connect) | 14 |
| Phase 4 (US2 - Mode Switch) | 16 |
| Phase 5 (US3 - Status) | 8 |
| Phase 6 (Polish) | 7 |
| Parallel Opportunities | 12 |

### MVP Scope

**Minimum**: Phase 1 + Phase 2 + Phase 3 (US1) = 24 tasks
**Result**: Reliable Connect/Disconnect with LocalProcessEngine

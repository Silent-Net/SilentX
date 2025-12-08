# Tasks: SilentX - User-Friendly macOS Proxy Tool

**Input**: Design documents from `/specs/001-macos-proxy-gui/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Required by constitution (Test-First Delivery). Every user story includes tests that must be written first and fail before implementation.

**Organization**: Tasks grouped by user story to enable independent implementation and testing. IDs are sequential; use `[P]` for safe parallel work and `[USn]` for story mapping. All paths are repository-relative.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Ensure test harness, metrics, and logging are ready before story work.

- [x] T001 Create SwiftUI test fixtures and shared XCT utilities for UI flows in SilentXUITests/Support/TestHarness.swift
- [x] T002 [P] Add OSLog-based telemetry helper for timing launch/connect/config validation in SilentX/SilentX/Services/PerformanceMetrics.swift
- [x] T003 [P] Add feature-flag/toggle struct for proxy/core/test stubs in SilentX/SilentX/Shared/FeatureFlags.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that all stories rely on. No story work starts until this phase completes.

- [x] T004 Add CI entrypoint (Makefile or fastlane lane) to run unit + UI tests headless in .github/workflows/ci.yml
- [x] T005 [P] Add XCTest performance harness with thresholds config (launch/connect/validation/core switch) in SilentXUITests/PerformanceMetricsTests.swift
- [x] T006 [P] Add OSLog categories and redaction policy for sensitive data in SilentX/SilentX/Services/LogService.swift
- [x] T007 [P] Add deterministic sample data loaders for SwiftUI previews/tests in SilentX/SilentX/Preview Content/PreviewData.swift
- [x] T008 Add crash/abort guard and window restoration disable toggle for test runs in SilentX/SilentX/SilentXApp.swift

**Checkpoint**: Test harness, telemetry, CI, and logging ready; user stories may proceed.

---

## Phase 3: User Story 1 - Connect to Proxy Server (Priority: P1) 🎯 MVP

**Goal**: User can select a profile and connect/disconnect; system proxy is enabled/restored; failures surface clearly.

**Independent Test**: Launch app with a preconfigured profile, tap Connect, observe status transition and proxy rollback on failure.

### Tests (write first, must fail initially)

- [x] T009 [US1] UI test: connect/disconnect happy path and status assertions in SilentXUITests/ConnectFlowTests.swift
- [x] T010 [US1] UI test: proxy enable failure shows error and rolls back in SilentXUITests/ConnectFlowTests.swift
- [x] T011 [US1] Unit test: SystemProxyService enable/restore no-op fallback when permissions missing in SilentXTests/SystemProxyServiceTests.swift
- [x] T012 [US1] Unit test: ConnectionService watchdog surfaces error on core crash and restores proxy in SilentXTests/ConnectionServiceTests.swift

### Implementation

- [x] T013 [US1] Implement SystemProxyService safe detection + enable/restore with permission-aware fallbacks in SilentX/SilentX/Services/SystemProxyService.swift
- [x] T014 [US1] Integrate SystemProxyService sequencing into ConnectionService (proxy on after core up, off before stop) in SilentX/SilentX/Services/ConnectionService.swift
- [x] T015 [US1] Wire ConfigurationService.generateConfig + active profile into connect pipeline in SilentX/SilentX/Services/ConnectionService.swift
- [x] T016 [US1] Add core process crash/exit watchdog and status error surfacing in SilentX/SilentX/Services/ConnectionService.swift
- [x] T017 [US1] Update Dashboard ConnectButton/ConnectionStatusView UX for errors/progress in SilentX/SilentX/Views/Dashboard/

**Checkpoint**: US1 independently connect/disconnects with proxy enable/restore and crash-safe UX; tests pass.

---

## Phase 4: User Story 2 - Import Configuration Profile (Priority: P1)

**Goal**: Import from URL/file, validate, and support subscription auto-update with error handling.

**Independent Test**: Import valid/invalid configs; subscription auto-update retries/backoff with status UI.

### Tests (write first, must fail initially)

- [x] T018 [US2] UI test: ProfileListView renders without crash with empty/populated data in SilentXUITests/ProfileListCrashTests.swift
- [x] T019 [US2] UI test: import from URL/file success and invalid JSON rejection in SilentXUITests/ImportProfileTests.swift
- [x] T020 [US2] Unit test: subscription updater honors ETag/Last-Modified, backoff, and merges without clobbering edits in SilentXTests/ProfileServiceSubscriptionTests.swift
- [x] T021 [US2] UI test: subscription auto-update toggle, last-sync display, and error banner in SilentXUITests/ImportProfileTests.swift
- [x] T022 [US2] UI test: offline/network-unavailable error handling with retry guidance in SilentXUITests/ImportProfileTests.swift

### Implementation

- [x] T023 [US2] Extend Profile model with subscription metadata (etag/lastModified/lastSyncAt/autoUpdate flag) and migration in SilentX/SilentX/Models/Profile.swift
- [x] T024 [US2] Implement subscription updater with retry/backoff + merge/validation in SilentX/SilentX/Services/ProfileService.swift
- [x] T025 [US2] Add auto-update controls and status UI in SilentX/SilentX/Views/Profiles/ProfileDetailView.swift

**Checkpoint**: US2 independently imports and auto-updates profiles with clear errors; tests pass.

---

## Phase 5: User Story 3 - Manage Proxy Nodes via GUI (Priority: P2)

**Goal**: Add/edit/delete nodes with real latency measurement surfaced in UI.

**Independent Test**: Add node, measure latency, edit/delete with confirmations.

### Tests (write first, must fail initially)

- [ ] T026 [US3] UI test: add/edit/delete node flows and drag-reorder in SilentXUITests/NodeManagementTests.swift
- [ ] T027 [US3] Unit test: NodeService real latency probe with timeout/backoff in SilentXTests/NodeServiceLatencyTests.swift
- [ ] T028 [US3] UI test: latency display expectations with periodic refresh and failure states in SilentXUITests/NodeManagementTests.swift

### Implementation

- [ ] T029 [US3] Implement real latency probe (TCP/QUIC) and expose status in NodeService in SilentX/SilentX/Services/NodeService.swift
- [ ] T030 [US3] Surface latency/status refresh in NodeRowView/NodeListView with failure states in SilentX/SilentX/Views/Nodes/

**Checkpoint**: US3 GUI with latency works independently; tests pass.

---

## Phase 6: User Story 4 - Manage Routing Rules via GUI (Priority: P2)

**Goal**: Create/edit/reorder rules with validation by match type.

**Independent Test**: Create domain/IP/process rules; reorder updates evaluation.

### Tests (write first, must fail initially)

- [ ] T031 [US4] UI test: rule create/edit/reorder for domain/IP/process types in SilentXUITests/RuleManagementTests.swift
- [ ] T032 [US4] Unit test: RuleService validation per match type and duplicate detection in SilentXTests/RuleServiceValidationTests.swift
- [ ] T033 [US4] UI test: rule CRUD and drag-to-reorder priority in SilentXUITests/RuleManagementTests.swift

### Implementation

- [ ] T034 [US4] Enhance RuleService validation and duplicate prevention in SilentX/SilentX/Services/RuleService.swift
- [ ] T035 [US4] Ensure drag-reorder updates persisted order and reflects in UI in SilentX/SilentX/Views/Rules/

**Checkpoint**: US4 rules manageable via GUI with validation; tests pass.

---

## Phase 7: User Story 5 - Manage Sing-Box Core Versions (Priority: P3)

**Goal**: Download/switch/auto-update cores with verification and rollback.

**Independent Test**: Download new core, verify hash, switch active, rollback on failure.

### Tests (write first, must fail initially)

- [ ] T036 [US5] Unit test: CoreVersionService download + hash verification + rollback on failure in SilentXTests/CoreVersionServiceTests.swift
- [ ] T037 [US5] UI test: switch core version and reflect active state in SilentXUITests/CoreVersionUITests.swift
- [ ] T038 [US5] Unit test: core version download, switch, and fallback to bundled version when missing in SilentXTests/CoreVersionServiceTests.swift

### Implementation

- [ ] T039 [US5] Add hash verification and rollback for failed downloads in SilentX/SilentX/Services/CoreVersionService.swift
- [ ] T040 [US5] Update CoreVersionListView to surface verification/rollback states in SilentX/SilentX/Views/Settings/CoreVersionListView.swift

**Checkpoint**: US5 core management works with verification; tests pass.

---

## Phase 8: User Story 6 - Edit Raw JSON Configuration (Priority: P3)

**Goal**: JSON editor with highlighting, real-time validation, and safe apply.

**Independent Test**: Edit JSON, see inline validation, apply changes safely.

### Tests (write first, must fail initially)

- [ ] T041 [US6] UI test: JSON editor highlights, shows validation errors, and prevents invalid save in SilentXUITests/JSONEditorTests.swift
- [ ] T042 [US6] Unit test: ConfigurationService validation errors include line/column and merge safety in SilentXTests/ConfigurationServiceValidationTests.swift
- [ ] T043 [US6] UI test: JSON editor highlighting, validation errors, and save/apply flow in SilentXUITests/JSONEditorTests.swift

### Implementation

- [ ] T044 [US6] Enhance JSONEditorView with inline error display and guarded save in SilentX/SilentX/Views/Profiles/JSONEditorView.swift
- [ ] T045 [US6] Improve ConfigurationService validation/merge error reporting with positions in SilentX/SilentX/Services/ConfigurationService.swift

**Checkpoint**: US6 advanced JSON editing works with safety; tests pass.

---

## Phase 9: Cross-Cutting - Observability & Performance Gates

**Purpose**: Enforce success criteria (launch <3s, connect <5s, validation <1s, core switch <10s).

### Tests (write first)

- [ ] T046 [P] Add XCTest performance assertions: launch <3s, connect <5s, validation <1s, core-switch <10s (fail if exceeded) in SilentXUITests/PerformanceMetricsTests.swift
- [ ] T047 [P] Add UI performance smoke tests measuring app launch and connect latency using XCTMetric/custom timing in SilentXUITests/PerformanceMetricsTests.swift

### Implementation

- [ ] T048 Add instrumentation hooks for launch/connect/validation/core-switch timings in SilentX/SilentX/SilentXApp.swift and ConnectionService.swift
- [ ] T049 [P] Wire metrics export into LogService and surface perf warnings in-app in SilentX/SilentX/Services/LogService.swift and SilentX/SilentX/Views/Logs/LogView.swift

---

## Phase 10: Polish & Hardening

**Purpose**: Final stability, docs, and quickstart validation.

- [ ] T050 Add user-facing error copy for proxy/core failures and recovery steps in SilentX/SilentX/Views/Dashboard/ConnectionStatusView.swift
- [ ] T051 [P] Update quickstart.md with proxy permissions, subscription auto-update, and perf gates in specs/001-macos-proxy-gui/quickstart.md
- [ ] T052 [P] Add constitution gate checklist to quickstart.md and CI to ensure tests and performance targets run before merge
- [ ] T053 [P] Run full quickstart validation and record metrics baseline; document in specs/001-macos-proxy-gui/research.md

---

## ========== MVP GATE ==========

**Phases 1-10 constitute the MVP.** All tasks must be complete and tests passing before proceeding to Phase 11.

**MVP Validation Checklist:**
- [ ] All Phase 1-10 tasks completed
- [ ] All tests green (unit + UI + performance)
- [ ] Performance thresholds met (launch <3s, connect <5s, validation <1s)
- [ ] Quick start guide validated end-to-end
- [ ] User can import profile, connect/disconnect with simulation
- [ ] No CRITICAL or HIGH severity bugs

**Post-MVP phases deliver real core integration, Network Extension, and advanced features.**

---

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (Phase 1) → Foundational (Phase 2) → User Stories (Phases 3-8) → Cross-Cutting (Phase 9) → Polish (Phase 10).
- User stories start only after Phase 2 completes. US1/US2 (P1) before P2 stories if capacity is limited.

### User Story Dependencies

- US1 (Connect) depends on Phase 2; must complete before perf gates are meaningful.
- US2 (Import) depends on Phase 2; independent of US1 but shares ConfigurationService.
- US3 (Nodes) depends on US2 data presence but can proceed after Phase 2 with mocks.
- US4 (Rules) depends on Phase 2; optional linkage to US2 profiles.
- US5 (Core Versions) depends on Phase 2 only.
- US6 (JSON Editor) depends on US2 profile detail view.

### Parallel Opportunities

- Phase 1: T002, T003 can run in parallel after T001 scaffold.
- Phase 2: T005-T007 can run in parallel after CI scaffold T004.
- Story tests within each phase marked [P] can be authored concurrently (e.g., T009-T011, T018-T020).
- Different user stories (e.g., US3 and US4) can proceed in parallel once Phase 2 is done.

---

## Implementation Strategy

- **MVP Scope**: Complete Phases 1-4 (US1 + US2) with passing tests and perf instrumentation hooks; stop and validate.
- **Incremental**: Add US3/US4 (P2), then US5/US6 (P3), enforcing perf gates (Phase 9) before release hardening (Phase 10).
# Tasks: SilentX - User-Friendly macOS Proxy Tool

**Input**: Design documents from `/specs/001-macos-proxy-gui/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Not explicitly requested in spec. Tests omitted per template guidelines.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1-US6) this task belongs to
- Exact file paths included in all descriptions

## Path Conventions

Based on plan.md project structure:
- Main app: `SilentX/SilentX/`
- Models: `SilentX/SilentX/Models/`
- Views: `SilentX/SilentX/Views/`
- Services: `SilentX/SilentX/Services/`
- Shared: `SilentX/Shared/`

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Project initialization, folder structure, basic app shell

- [x] T001 Create folder structure per plan.md in SilentX/SilentX/
- [x] T002 [P] Create Models/ directory in SilentX/SilentX/Models/
- [x] T003 [P] Create Views/ directory with subdirectories in SilentX/SilentX/Views/
- [x] T004 [P] Create Services/ directory in SilentX/SilentX/Services/
- [x] T005 [P] Create Shared/ directory at SilentX/Shared/
- [x] T006 Configure SwiftData ModelContainer in SilentX/SilentX/SilentXApp.swift
- [x] T007 Create FilePath constants in SilentX/Shared/FilePath.swift
- [x] T008 Create Constants.swift with app-wide constants in SilentX/Shared/Constants.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure required by ALL user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### SwiftData Models (All Stories Depend On)

- [x] T009 Create ProfileType enum in SilentX/SilentX/Models/ProfileType.swift
- [x] T010 [P] Create ProxyProtocol enum in SilentX/SilentX/Models/ProxyProtocol.swift
- [x] T011 [P] Create RuleMatchType enum in SilentX/SilentX/Models/RuleMatchType.swift
- [x] T012 [P] Create RuleAction enum in SilentX/SilentX/Models/RuleAction.swift
- [x] T013 Create Profile @Model class with relationships in SilentX/SilentX/Models/Profile.swift
- [x] T014 [P] Create ProxyNode @Model class in SilentX/SilentX/Models/ProxyNode.swift
- [x] T015 [P] Create RoutingRule @Model class in SilentX/SilentX/Models/RoutingRule.swift
- [x] T016 [P] Create CoreVersion @Model class in SilentX/SilentX/Models/CoreVersion.swift

### Navigation Infrastructure (All Views Depend On)

- [x] T017 Create NavigationItem enum for sidebar items in SilentX/SilentX/Views/NavigationItem.swift
- [x] T018 Create MainView with NavigationSplitView in SilentX/SilentX/Views/MainView.swift
- [x] T019 Create SidebarView with navigation list in SilentX/SilentX/Views/SidebarView.swift
- [x] T020 Update ContentView to use MainView in SilentX/SilentX/ContentView.swift
- [x] T021 Create DetailView router for navigation selection in SilentX/SilentX/Views/DetailView.swift

### Connection State (Dashboard & Connection Depend On)

- [x] T022 Create ConnectionStatus enum in SilentX/SilentX/Services/ConnectionStatus.swift
- [x] T023 Create ConnectionService protocol stub in SilentX/SilentX/Services/ConnectionService.swift

**Checkpoint**: Foundation ready - NavigationSplitView shell working, SwiftData models defined

---

## Phase 3: User Story 1 - Connect to Proxy Server (P1) 🎯 MVP

**Goal**: Users can launch app, select profile, click Connect/Disconnect button
**⚠️ MOCK IMPLEMENTATION**: This phase delivers UI/UX with simulated connection state. Real Sing-Box core integration and system proxy control deferred to Post-MVP Phases 11-12.
**Independent Test**: Launch app with pre-configured profile, click Connect, verify status indicator changes

### Dashboard Views for US1

- [x] T024 [US1] Create DashboardView with connection status in SilentX/SilentX/Views/Dashboard/DashboardView.swift
- [x] T025 [US1] Create ConnectionStatusView indicator component in SilentX/SilentX/Views/Dashboard/ConnectionStatusView.swift
- [x] T026 [US1] Create ConnectButton with connect/disconnect actions in SilentX/SilentX/Views/Dashboard/ConnectButton.swift
- [x] T027 [US1] Create ProfileSelectorView dropdown in SilentX/SilentX/Views/Dashboard/ProfileSelectorView.swift
- [x] T028 [US1] Create StatisticsView for upload/download stats in SilentX/SilentX/Views/Dashboard/StatisticsView.swift
- [x] T029 [US1] Integrate Dashboard components into DashboardView in SilentX/SilentX/Views/Dashboard/DashboardView.swift

### Connection Service for US1

- [x] T030 [US1] Implement ConnectionService with mock status in SilentX/SilentX/Services/ConnectionService.swift
- [x] T031 [US1] Add status publisher using Combine in SilentX/SilentX/Services/ConnectionService.swift
- [x] T032 [US1] Implement connect/disconnect state transitions in SilentX/SilentX/Services/ConnectionService.swift

### Profile Selection for US1

- [x] T033 [US1] Create ProfileService protocol in SilentX/SilentX/Services/ProfileService.swift
- [x] T034 [US1] Implement getActiveProfile and setActiveProfile in SilentX/SilentX/Services/ProfileService.swift

**Checkpoint**: User Story 1 complete - Dashboard shows connection status, Connect/Disconnect works with mock data

---

## Phase 4: User Story 2 - Import Configuration Profile (P1) 🎯 MVP

**Goal**: Users can import profiles from URL, file, or subscription link

**Independent Test**: Import a configuration file, verify profile appears in list with correct settings

### Profile List Views for US2

- [x] T035 [P] [US2] Create ProfileListView with SwiftData @Query in SilentX/SilentX/Views/Profiles/ProfileListView.swift
- [x] T036 [P] [US2] Create ProfileRowView for list items in SilentX/SilentX/Views/Profiles/ProfileRowView.swift
- [x] T037 [US2] Create ProfileDetailView for viewing profile info in SilentX/SilentX/Views/Profiles/ProfileDetailView.swift
- [x] T038 [US2] Create EmptyProfilesView with import guidance in SilentX/SilentX/Views/Profiles/EmptyProfilesView.swift

### Import Views for US2

- [x] T039 [US2] Create ImportProfileSheet modal view in SilentX/SilentX/Views/Profiles/ImportProfileSheet.swift
- [x] T040 [P] [US2] Create ImportURLView for URL import in SilentX/SilentX/Views/Profiles/ImportURLView.swift
- [x] T041 [P] [US2] Create ImportFileView for file import in SilentX/SilentX/Views/Profiles/ImportFileView.swift

### Profile Service for US2

- [x] T042 [US2] Implement ProfileService CRUD operations in SilentX/SilentX/Services/ProfileService.swift
- [x] T043 [US2] Implement importFromURL with URLSession in SilentX/SilentX/Services/ProfileService.swift
- [x] T044 [US2] Implement importFromFile with file reading in SilentX/SilentX/Services/ProfileService.swift
- [x] T045 [US2] Implement exportToJSON for profile export in SilentX/SilentX/Services/ProfileService.swift

### Configuration Validation for US2

- [x] T046 [US2] Create ConfigurationService protocol in SilentX/SilentX/Services/ConfigurationService.swift
- [x] T047 [US2] Implement JSON validation in ConfigurationService in SilentX/SilentX/Services/ConfigurationService.swift
- [x] T048 [US2] Create ProfileError enum with localized messages in SilentX/SilentX/Services/ProfileError.swift

### Drag & Drop Support for US2

- [x] T049 [US2] Add file drag-drop support to ProfileListView in SilentX/SilentX/Views/Profiles/ProfileListView.swift

**Checkpoint**: User Story 2 complete - Can import profiles from URL/file, profile list shows imported profiles

---

## Phase 5: User Story 3 - Manage Proxy Nodes via GUI (P2)

**Goal**: Users can add, edit, delete proxy nodes through visual interface

**Independent Test**: Add a new node via GUI, verify it appears in list and can be used for connection

### Node List Views for US3

- [x] T050 [P] [US3] Create NodeListView with SwiftData @Query in SilentX/SilentX/Views/Nodes/NodeListView.swift
- [x] T051 [P] [US3] Create NodeRowView for list items with latency in SilentX/SilentX/Views/Nodes/NodeRowView.swift
- [x] T052 [US3] Create NodeDetailView for viewing node properties in SilentX/SilentX/Views/Nodes/NodeDetailView.swift

### Node Editor Views for US3

- [x] T053 [US3] Create AddNodeSheet form modal in SilentX/SilentX/Views/Nodes/AddNodeSheet.swift
- [x] T054 [US3] Create EditNodeSheet for editing existing nodes in SilentX/SilentX/Views/Nodes/EditNodeSheet.swift
- [x] T055 [P] [US3] Create protocol-specific credential forms:
  - ShadowsocksFieldsView in SilentX/SilentX/Views/Nodes/ProtocolFields/ShadowsocksFieldsView.swift
- [x] T056 [P] [US3] Create VMess/VLESS credential fields in SilentX/SilentX/Views/Nodes/ProtocolFields/VMESSFieldsView.swift
- [x] T057 [P] [US3] Create Trojan credential fields in SilentX/SilentX/Views/Nodes/ProtocolFields/TrojanFieldsView.swift
- [x] T058 [P] [US3] Create Hysteria2 credential fields in SilentX/SilentX/Views/Nodes/ProtocolFields/Hysteria2FieldsView.swift
- [x] T059 [US3] Create dynamic ProtocolFieldsView switcher in SilentX/SilentX/Views/Nodes/ProtocolFields/ProtocolFieldsView.swift

### Node Service for US3

- [x] T060 [US3] Create NodeService protocol in SilentX/SilentX/Services/NodeService.swift
- [x] T061 [US3] Implement NodeService CRUD operations in SilentX/SilentX/Services/NodeService.swift
- [x] T062 [US3] Implement node validation logic in SilentX/SilentX/Services/NodeService.swift
- [x] T063 [US3] Implement testLatency STUB (returns mock 50ms latency; real TCP/QUIC probe in Post-MVP T140-T141) in SilentX/SilentX/Services/NodeService.swift
- [x] T064 [US3] Create NodeError enum with localized messages in SilentX/SilentX/Services/NodeError.swift

### Node Reordering for US3

- [x] T065 [US3] Add drag-to-reorder support in NodeListView in SilentX/SilentX/Views/Nodes/NodeListView.swift

**Checkpoint**: User Story 3 complete - Can add/edit/delete nodes via GUI, protocol-specific forms work

---

## Phase 6: User Story 4 - Manage Routing Rules via GUI (P2)

**Goal**: Users can create and manage routing rules through visual interface

**Independent Test**: Create routing rule via GUI, verify specific domains route as configured

### Rule List Views for US4

- [x] T066 [P] [US4] Create RuleListView with SwiftData @Query in SilentX/SilentX/Views/Rules/RuleListView.swift
- [x] T067 [P] [US4] Create RuleRowView for list items in SilentX/SilentX/Views/Rules/RuleRowView.swift
- [x] T068 [US4] Create RuleDetailView for viewing rule properties in SilentX/SilentX/Views/Rules/RuleDetailView.swift

### Rule Editor Views for US4

- [x] T069 [US4] Create AddRuleSheet form modal in SilentX/SilentX/Views/Rules/AddRuleSheet.swift
- [x] T070 [US4] Create EditRuleSheet for editing existing rules in SilentX/SilentX/Views/Rules/EditRuleSheet.swift
- [x] T071 [US4] Create MatchTypePicker for rule match types in SilentX/SilentX/Views/Rules/MatchTypePicker.swift
- [x] T072 [US4] Create ActionPicker for rule actions in SilentX/SilentX/Views/Rules/ActionPicker.swift

### Rule Templates for US4

- [x] T073 [US4] Create RuleTemplate struct in SilentX/SilentX/Models/RuleTemplate.swift
- [x] T074 [US4] Create RuleTemplatesView with common templates in SilentX/SilentX/Views/Rules/RuleTemplatesView.swift

### Rule Service for US4

- [x] T075 [US4] Create RuleService protocol in SilentX/SilentX/Services/RuleService.swift
- [x] T076 [US4] Implement RuleService CRUD operations in SilentX/SilentX/Services/RuleService.swift
- [x] T077 [US4] Implement rule validation by match type in SilentX/SilentX/Services/RuleService.swift
- [x] T078 [US4] Implement getRuleTemplates with common patterns in SilentX/SilentX/Services/RuleService.swift
- [x] T079 [US4] Create RuleError enum with localized messages in SilentX/SilentX/Services/RuleError.swift

### Rule Reordering for US4

- [x] T080 [US4] Add drag-to-reorder support for priority in RuleListView in SilentX/SilentX/Views/Rules/RuleListView.swift

**Checkpoint**: User Story 4 complete - Can add/edit/delete/reorder rules via GUI, templates available

---

## Phase 7: User Story 5 - Manage Sing-Box Core Versions (P3)

**Goal**: Users can download, switch between, and auto-update core versions

**Independent Test**: Download different core version, switch to it, verify app operates with new core

### Core Version Views for US5

- [x] T081 [P] [US5] Create CoreVersionListView in SilentX/SilentX/Views/Settings/CoreVersionListView.swift
- [x] T082 [P] [US5] Create CoreVersionRowView with status indicators in SilentX/SilentX/Views/Settings/CoreVersionRowView.swift
- [x] T083 [US5] Create DownloadCoreSheet with URL input and progress in SilentX/SilentX/Views/Settings/DownloadCoreSheet.swift
- [x] T084 [US5] Create AvailableVersionsView for GitHub releases in SilentX/SilentX/Views/Settings/AvailableVersionsView.swift

### Core Version Service for US5

- [x] T085 [US5] Create CoreVersionService protocol in SilentX/SilentX/Services/CoreVersionService.swift
- [x] T086 [US5] Implement getCachedVersions and getActiveVersion in SilentX/SilentX/Services/CoreVersionService.swift
- [x] T087 [US5] Implement downloadVersion with progress callback in SilentX/SilentX/Services/CoreVersionService.swift
- [x] T088 [US5] Implement downloadFromURL for custom URLs in SilentX/SilentX/Services/CoreVersionService.swift
- [x] T089 [US5] Implement setActiveVersion and deleteVersion in SilentX/SilentX/Services/CoreVersionService.swift
- [x] T090 [US5] Implement checkForUpdates using GitHub API in SilentX/SilentX/Services/CoreVersionService.swift
- [x] T091 [US5] Create CoreVersionError enum with localized messages in SilentX/SilentX/Services/CoreVersionError.swift

### Auto-Update for US5

- [x] T092 [US5] Add auto-update toggle in Settings in SilentX/SilentX/Views/Settings/SettingsView.swift
- [x] T093 [US5] Implement background update check in CoreVersionService in SilentX/SilentX/Services/CoreVersionService.swift

**Checkpoint**: User Story 5 complete - Can download/switch/auto-update core versions

---

## Phase 8: User Story 6 - Edit Raw JSON Configuration (P3)

**Goal**: Advanced users can edit JSON with syntax highlighting and validation

**Independent Test**: Edit JSON directly, verify changes saved and applied correctly

### JSON Editor Views for US6

- [x] T094 [P] [US6] Create JSONEditorView with TextEditor in SilentX/SilentX/Views/Profiles/JSONEditorView.swift
- [x] T095 [US6] Add syntax highlighting using AttributedString in SilentX/SilentX/Views/Profiles/JSONEditorView.swift
- [x] T096 [US6] Create ValidationErrorsView for displaying errors in SilentX/SilentX/Views/Profiles/ValidationErrorsView.swift
- [x] T097 [US6] Add real-time validation with debounce in SilentX/SilentX/Views/Profiles/JSONEditorView.swift

### Configuration Service for US6

- [x] T098 [US6] Implement parseNodes for JSON extraction in SilentX/SilentX/Services/ConfigurationService.swift
- [x] T099 [US6] Implement parseRules for JSON extraction in SilentX/SilentX/Services/ConfigurationService.swift
- [x] T100 [US6] Implement generateConfig from Profile model in SilentX/SilentX/Services/ConfigurationService.swift
- [x] T101 [US6] Create ConfigValidationResult and ConfigValidationError in SilentX/SilentX/Services/ConfigurationService.swift

### Integration for US6

- [x] T102 [US6] Add "Edit JSON" button to ProfileDetailView in SilentX/SilentX/Views/Profiles/ProfileDetailView.swift
- [x] T103 [US6] Sync JSON edits back to Profile.configurationJSON in SilentX/SilentX/Views/Profiles/JSONEditorView.swift

**Checkpoint**: User Story 6 complete - JSON editing with highlighting and validation works

---

## Phase 9: Log Viewer (Cross-Cutting)

**Purpose**: Built-in log viewer requested in spec clarifications

### Tests (write first, must fail initially)

- [ ] T104A Unit test: LogService filtering by level (error/warning/info/debug) returns correct entries in SilentXTests/LogServiceTests.swift
- [ ] T104B Unit test: LogService filtering by category returns correct entries in SilentXTests/LogServiceTests.swift
- [ ] T104C Unit test: LogService export to file produces valid JSON with all entries in SilentXTests/LogServiceTests.swift
- [ ] T104D UI test: LogView displays filtered entries based on level picker selection in SilentXUITests/LogViewTests.swift
- [ ] T104E UI test: LogView real-time streaming shows new entries without refresh in SilentXUITests/LogViewTests.swift

### Implementation

- [x] T104 [P] Create LogLevel enum in SilentX/SilentX/Services/LogLevel.swift
- [x] T105 [P] Create LogEntry struct in SilentX/SilentX/Services/LogEntry.swift
- [x] T106 [P] Create LogFilter struct in SilentX/SilentX/Services/LogFilter.swift
- [x] T107 Create LogService protocol in SilentX/SilentX/Services/LogService.swift
- [x] T108 Implement LogService with mock log generation in SilentX/SilentX/Services/LogService.swift
- [x] T109 Create LogView with filtering in SilentX/SilentX/Views/Logs/LogView.swift
- [x] T110 [P] Create LogEntryRowView in SilentX/SilentX/Views/Logs/LogEntryRowView.swift
- [x] T111 [P] Create LogFilterView for level/category filtering in SilentX/SilentX/Views/Logs/LogFilterView.swift
- [x] T112 Implement log export to file in LogService in SilentX/SilentX/Services/LogService.swift

---

## Phase 10: Settings & Polish

**Purpose**: Settings view and cross-cutting improvements

### Settings Views

- [x] T113 Create SettingsView with sections in SilentX/SilentX/Views/Settings/SettingsView.swift
- [x] T114 [P] Create GeneralSettingsView in SilentX/SilentX/Views/Settings/GeneralSettingsView.swift
- [x] T115 [P] Create AppearanceSettingsView in SilentX/SilentX/Views/Settings/AppearanceSettingsView.swift
- [x] T116 Create AboutView with version info in SilentX/SilentX/Views/Settings/AboutView.swift

### Polish & UX

- [x] T117 Create WelcomeView for first launch onboarding in SilentX/SilentX/Views/Onboarding/WelcomeView.swift
- [x] T118 Add first-launch detection in SilentXApp in SilentX/SilentX/SilentXApp.swift
- [x] T119 Add SwiftUI previews to all views
- [x] T120 Create sample data for previews in SilentX/SilentX/Preview Content/PreviewData.swift
- [x] T121 Add confirmation dialogs for destructive actions
- [x] T122 Add loading states and progress indicators
- [x] T123 Run quickstart.md validation to ensure app builds and runs

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ────────────────────────────────────────┐
                                                        │
Phase 2: Foundational ─────────────────────────────────┤ BLOCKS all user stories
                                                        │
        ┌───────────────────────────────────────────────┘
        │
        ├── Phase 3: US1 - Connect (P1) ───────┐
        │                                       │
        ├── Phase 4: US2 - Import (P1) ────────┤ MVP
        │                                       │
        ├── Phase 5: US3 - Nodes (P2) ─────────┤
        │                                       │
        ├── Phase 6: US4 - Rules (P2) ─────────┤
        │                                       │
        ├── Phase 7: US5 - Core Versions (P3) ─┤
        │                                       │
        └── Phase 8: US6 - JSON Editor (P3) ───┘
                                                
Phase 9: Log Viewer ───────────────────────────────────┤ After Phase 2
                                                        │
Phase 10: Settings & Polish ───────────────────────────┘ After all user stories
```

### User Story Dependencies

| User Story | Depends On | Can Start After |
|------------|------------|-----------------|
| US1 (Connect) | Phase 2 | Foundational complete |
| US2 (Import) | Phase 2 | Foundational complete |
| US3 (Nodes) | Phase 2, benefits from US2 | Foundational complete |
| US4 (Rules) | Phase 2, benefits from US2 | Foundational complete |
| US5 (Core) | Phase 2 | Foundational complete |
| US6 (JSON) | Phase 2, US2 | US2 ProfileDetailView exists |

### Within Each User Story

1. Views before service integration
2. Service protocol before implementation
3. CRUD operations before advanced features
4. Core functionality before polish

### Parallel Opportunities

**Phase 1 (all [P] can run together):**
```
T002, T003, T004, T005 - Directory creation
```

**Phase 2 (after enums):**
```
T010, T011, T012 - Enum definitions
T014, T015, T016 - Model definitions
```

**User Stories (after Phase 2 complete):**
```
US1 and US2 can run in parallel (different views/services)
US3 and US4 can run in parallel (different views/services)
US5 and US6 can run in parallel (different views/services)
```

---

## Parallel Example: Phase 2 Models

```bash
# After T009 (ProfileType enum), launch these in parallel:
T010: "Create ProxyProtocol enum in SilentX/SilentX/Models/ProxyProtocol.swift"
T011: "Create RuleMatchType enum in SilentX/SilentX/Models/RuleMatchType.swift"
T012: "Create RuleAction enum in SilentX/SilentX/Models/RuleAction.swift"

# After T013 (Profile model), launch these in parallel:
T014: "Create ProxyNode @Model class in SilentX/SilentX/Models/ProxyNode.swift"
T015: "Create RoutingRule @Model class in SilentX/SilentX/Models/RoutingRule.swift"
T016: "Create CoreVersion @Model class in SilentX/SilentX/Models/CoreVersion.swift"
```

---

## Implementation Strategy

### MVP Delivery (US1 + US2)

1. Complete Phase 1: Setup (T001-T008)
2. Complete Phase 2: Foundational (T009-T023)
3. Complete Phase 3: User Story 1 - Connect (T024-T034)
4. Complete Phase 4: User Story 2 - Import (T035-T049)
5. **STOP and VALIDATE**: Test import and connect flow
6. Deploy/demo MVP

**MVP Deliverable**: App with NavigationSplitView, Dashboard with connect/disconnect, Profile import from URL/file

### Incremental Delivery

| Increment | User Stories | Value Delivered |
|-----------|--------------|-----------------|
| MVP | US1 + US2 | Basic proxy management |
| +1 | US3 | Visual node editing |
| +2 | US4 | Visual rule editing |
| +3 | US5 | Core version management |
| +4 | US6 | Advanced JSON editing |
| +5 | Phase 9-10 | Logs, settings, polish |

---

## ========== POST-MVP PHASES ==========

## Post-MVP Phase 11: Core Integration (US1) 

- [ ] T124 [US1] Replace ConnectionService mock connect/disconnect with real Sing-Box core start/stop using generated config in SilentX/SilentX/Services/ConnectionService.swift; launch bundled core binary and manage process handles.
- [ ] T125 [US1] Add core crash/exit watchdog and surface errors to Dashboard status (SilentX/SilentX/Services/ConnectionService.swift and SilentX/SilentX/Views/Dashboard/ConnectionStatusView.swift).
- [ ] T126 [US1] Wire ConfigurationService.generateConfig output and active profile selection into connect pipeline so core reads the selected profile’s config before start.

## Post-MVP Phase 12: System Proxy Control (US1)

- [ ] T127 [US1] Implement SystemProxyService to enable/restore macOS system proxy with backup and rollback on failure in SilentX/SilentX/Services/SystemProxyService.swift.
- [ ] T128 [US1] Integrate SystemProxyService into ConnectionService sequencing (proxy on after core up; proxy off before core stop) in SilentX/SilentX/Services/ConnectionService.swift.
- [ ] T129 [US1] Add admin permission and error-handling UX for proxy enable/restore in SilentX/SilentX/Views/Dashboard/ConnectButton.swift and ConnectionStatusView.

## Post-MVP Phase 13: Subscription Auto-Update (US2)

- [ ] T130 [US2] Extend Profile model with subscription metadata (source URL, etag/last-modified, lastSyncAt, autoUpdate flag) in SilentX/SilentX/Models/Profile.swift and migrate existing data.
- [ ] T131 [US2] Implement background subscription updater with ETag/Last-Modified checks, retry/backoff, and error surfacing in SilentX/SilentX/Services/ProfileService.swift.
- [ ] T132 [US2] Implement safe merge/validation for subscription updates to avoid clobbering user edits; reject invalid payloads with clear errors in SilentX/SilentX/Services/ProfileService.swift.
- [ ] T133 [US2] Add UI controls for auto-update toggle, last-sync status, and manual refresh in SilentX/SilentX/Views/Profiles/ProfileDetailView.swift.

## Post-MVP Phase 14: Quality Gates and Tests

- [ ] T134 Add UI tests for connect/disconnect happy and failure paths, including proxy restore verification, in SilentXUITests/SilentXUITests.swift.
- [ ] T135 Add performance smoke tests measuring app launch and connect latency (fail when exceeding spec targets) using XCTMetric/custom timing in SilentXUITests.
- [ ] T136 Add constitution gate checklist to quickstart.md and CI (if available) to ensure tests and performance targets run before merge.

## Post-MVP Phase 15: Network Extension Integration (US1)

- [ ] T137 [US1] Add macOS Network Extension target (PacketTunnelProvider scaffold) and host-app NETunnelProviderManager setup, including required entitlements and provisioning updates in SilentXExtension/ and project settings.
- [ ] T138 [US1] Implement start/stop bridge from ConnectionService to NETunnelProviderManager, passing generated configuration and handling tunnel state callbacks in SilentX/SilentX/Services/ConnectionService.swift.
- [ ] T139 [US1] Add System Extension packaging/signing steps for NE deployment (if required by distribution target) and document developer workflow in quickstart.md.

## Post-MVP Phase 16: Real Latency Measurement (US3)

- [ ] T140 [US3] Replace NodeService.testLatency stub with real TCP/QUIC latency probe and timeout/backoff handling in SilentX/SilentX/Services/NodeService.swift.
- [ ] T141 [US3] Surface measured latency/status in NodeRowView with periodic refresh and failure states in SilentX/SilentX/Views/Nodes/NodeRowView.swift and NodeListView.swift.

## Post-MVP Phase 17: Story Test Coverage

- [ ] T142 [US2] Add UI tests for profile import (URL and file) including invalid JSON rejection in SilentXUITests.
- [ ] T143 [US3] Add UI tests for add/edit/delete node flows and latency display expectations in SilentXUITests.
- [ ] T144 [US4] Add UI tests for rule CRUD and drag-to-reorder priority in SilentXUITests.
- [ ] T145 [US5] Add tests for core version download, switch, and fallback to bundled version when missing in SilentXTests.
- [ ] T146 [US6] Add UI tests for JSON editor highlighting, validation errors, and save/apply flow in SilentXUITests.
- [ ] T147 [US2] Add tests for subscription auto-update flows: ETag/Last-Modified reuse, invalid payload rejection, and last-sync UI status in SilentXTests/SilentXUITests.
- [ ] T148 [US1] Add crash watchdog test: simulate core/tunnel exit and assert proxy restoration, status error, and log entry are emitted in SilentXTests.

## Post-MVP Phase 18: Performance Instrumentation

- [ ] T149 Add in-app launch/connect timing instrumentation (OSLog metrics) and surface counters for perf tests to consume; gate thresholds per spec in SilentX/SilentX/SilentXApp.swift and ConnectionService.swift.

---

## Notes

- **[P]** tasks = different files, no dependencies, can run simultaneously
- **[USn]** label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All file paths are relative to repository root `/Users/xmx/workspace/Silent-Net/SilentX/`
- SwiftUI Previews should be used extensively during view development
- Use mock data for services until Phase 2 (Core Integration) of overall development

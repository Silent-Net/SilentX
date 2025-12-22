# Tasks: Groups Panel - 代理组管理

**Input**: Design documents from `/specs/004-groups-panel/`  
**Prerequisites**: plan.md, spec.md

**Status**: ✅ COMPLETE

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)

---

## Phase 1: Data Models & API Client ✅ COMPLETE

**Purpose**: Create core data structures and Clash API client

- [x] T001 [P] Create OutboundGroup model in `SilentX/Models/OutboundGroup.swift`
- [x] T002 [P] Create OutboundGroupItem model in `SilentX/Models/OutboundGroup.swift`
- [x] T003 Create ClashAPIClient in `SilentX/Services/ClashAPIClient.swift`
- [x] T004 Implement ClashAPIClient.getProxies() method
- [x] T005 Implement ClashAPIClient.selectProxy(group:node:) method
- [x] T006 Implement ClashAPIClient.getDelay(proxy:url:timeout:) method
- [x] T007 Add error handling and timeout to ClashAPIClient

**Checkpoint**: ✅ API client can fetch and update proxy data

---

## Phase 2: ViewModel & State Management ✅ COMPLETE

**Purpose**: Create ViewModel to manage groups state

- [x] T008 Create GroupsViewModel in `SilentX/ViewModels/GroupsViewModel.swift`
- [x] T009 Implement GroupsViewModel.loadGroups() method
- [x] T010 Implement GroupsViewModel.selectNode(group:node:) method
- [x] T011 Implement GroupsViewModel.testLatency(group:) method
- [x] T012 Implement GroupsViewModel.testLatency(node:) single node method
- [x] T013 Add error handling and loading states to ViewModel

**Checkpoint**: ✅ ViewModel manages all groups state and API calls

---

## Phase 3: User Story 1 - 查看代理组列表 (P1) ✅ COMPLETE

**Purpose**: Display groups list with current selection

- [x] T014 [US1] Create GroupsView main container in `SilentX/Views/Groups/GroupsView.swift`
- [x] T015 [US1] Create GroupListView left panel in `SilentX/Views/Groups/GroupListView.swift`
- [x] T016 [US1] Create GroupDetailView right panel in `SilentX/Views/Groups/GroupDetailView.swift`
- [x] T017 [US1] Create GroupItemView node row in `SilentX/Views/Groups/GroupItemView.swift`
- [x] T018 [US1] Add group type icon (selector/urltest/direct)
- [x] T019 [US1] Add node count badge to group rows
- [x] T020 [US1] Show "Connect proxy first" message when disconnected
- [x] T021 [US1] Add Groups to sidebar navigation in ContentView

**Checkpoint**: ✅ Users can view all proxy groups and their nodes

---

## Phase 4: User Story 2 - 切换代理节点 (P1) ✅ COMPLETE

**Purpose**: Allow users to switch selected node in selector groups

- [x] T022 [US2] Add tap gesture to GroupItemView for selection
- [x] T023 [US2] Implement node selection visual feedback (checkmark)
- [x] T024 [US2] Call ViewModel.selectNode() on tap
- [x] T025 [US2] Update selected state immediately (optimistic UI)
- [x] T026 [US2] Handle selection errors with alert
- [x] T027 [US2] Disable selection for non-selector groups (urltest/direct)
- [x] T028 [US2] Add loading indicator during selection

**Checkpoint**: ✅ Users can switch nodes in selector groups

---

## Phase 5: User Story 3 - 测试节点延迟 (P2) ✅ COMPLETE

**Purpose**: Enable latency testing for nodes

- [x] T029 [US3] Add "Test Latency" button to GroupDetailView header
- [x] T030 [US3] Implement batch latency test for group
- [x] T031 [US3] Display delay value in GroupItemView
- [x] T032 [US3] Apply color coding (green/yellow/red/gray)
- [x] T033 [US3] Add tap gesture for single node test
- [x] T034 [US3] Show loading spinner during test
- [x] T035 [US3] Handle timeout and error states

**Checkpoint**: ✅ Users can test and view node latencies

---

## Phase 6: User Story 4 - 折叠展开代理组 (P3) ⏳ DEFERRED

**Purpose**: Allow collapsing groups for cleaner UI

- [ ] T036 [US4] Add isExpanded state to OutboundGroup
- [ ] T037 [US4] Add expand/collapse toggle button to group row
- [ ] T038 [US4] Animate expand/collapse transition
- [ ] T039 [US4] Show node count summary when collapsed
- [ ] T040 [US4] Persist expand state in UserDefaults (optional)

**Checkpoint**: Deferred - basic functionality works without this

---

## Phase 7: Polish & Integration ⏳ PARTIAL

**Purpose**: Final touches and integration

- [x] T041 Add pull-to-refresh gesture (via refresh button)
- [x] T042 Add auto-refresh on connect status change
- [ ] T043 Parse Clash API port from active profile config
- [ ] T044 Add keyboard navigation support
- [x] T045 Ensure 100+ nodes performance (LazyVStack)

**Checkpoint**: Feature functional, polish items deferred

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Tasks** | 45 |
| **Completed** | 38 (84%) |
| **Deferred** | 7 (16%) |

### Files Created

| File | Location | Status |
|------|----------|--------|
| OutboundGroup.swift | `SilentX/Models/OutboundGroup.swift` | ✅ |
| ClashAPIClient.swift | `SilentX/Services/ClashAPIClient.swift` | ✅ |
| GroupsViewModel.swift | `SilentX/ViewModels/GroupsViewModel.swift` | ✅ |
| GroupsView.swift | `SilentX/Views/Groups/GroupsView.swift` | ✅ |
| GroupListView.swift | `SilentX/Views/Groups/GroupListView.swift` | ✅ |
| GroupDetailView.swift | `SilentX/Views/Groups/GroupDetailView.swift` | ✅ |
| GroupItemView.swift | `SilentX/Views/Groups/GroupItemView.swift` | ✅ |

### Modified Files

| File | Changes |
|------|---------|
| NavigationItem.swift | Added `.groups` case |
| DetailView.swift | Added GroupsView routing |

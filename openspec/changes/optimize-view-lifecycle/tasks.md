# Tasks: Optimize View Lifecycle Operations

## Phase 1: High-Priority Fixes (Navigation Panels)

- [x] **1.1** Fix `ConfigNodeListView` - Move JSON parsing to background thread
  - Add `Task.detached` wrapper around `parseNodes()`
  - Show loading indicator while parsing
  - Use preloaded data from `DetailView` if available

- [x] **1.2** Fix `ConfigRuleListView` - Move JSON parsing to background thread
  - Add `Task.detached` wrapper around `parseRules()`
  - Show loading indicator while parsing
  - Use preloaded data from `DetailView` if available

- [x] **1.3** Fix `GroupsView` - Ensure no blocking on panel switch
  - Verify `.task(id:)` only runs on connection status change
  - Add loading skeleton UI during data fetch
  - Ensure network call doesn't block main thread

## Phase 2: Medium-Priority Fixes (Dashboard/Settings)

- [x] **2.1** Fix `SystemProxyControlView` - Defer system proxy call
  - Move `applySystemProxy` to run after view appears with delay
  - Show subtle progress indicator during apply

- [ ] **2.2** Fix `ProxyModeSettingsView` - Optimize status checks
  - Cache extension status to avoid repeated checks
  - Run `checkExtensionStatus()` in background
  - Debounce `serviceStatusVM.startStatusRefresh()`

- [x] **2.3** Fix `DashboardView` - Add skip condition
  - Ensure `loadSavedProfile()` only runs if profile not yet loaded
  - Already partially fixed, verify behavior

## Phase 3: Low-Priority Fixes (Sheets/Modals)

- [x] **3.1** Fix `AvailableVersionsView` - Add loading state
  - Already has loading state, verify no blocking
  - Ensure network call is truly async

- [x] **3.2** Fix `LogView` - Verify service start is async
  - Ensure `logService.start()` doesn't block
  - Add initialization check to skip if already started

## Phase 4: Verification

- [ ] **4.1** Test rapid panel switching
  - Click all panels quickly, verify no lag
  - Verify no "layout recursion" warnings

- [ ] **4.2** Profile with Instruments
  - Use Time Profiler to verify main thread usage
  - Ensure frame times < 16ms during navigation

## Dependencies

- Tasks 1.1-1.3 can be done in parallel
- Tasks 2.1-2.3 can be done in parallel after Phase 1
- Phase 4 requires all other phases complete

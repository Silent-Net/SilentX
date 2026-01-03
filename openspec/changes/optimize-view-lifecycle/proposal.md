# Optimize View Lifecycle Operations

## Summary

Eliminate UI lag by fixing blocking operations in SwiftUI view lifecycle methods (`.onAppear`, `.task`). Currently, multiple views perform synchronous or slow async operations during view transitions, causing noticeable UI freeze when switching navigation panels.

## Problem

When users switch between navigation panels (Dashboard, Groups, Profiles, Nodes, Rules, Settings), there is significant lag due to:

1. **Network calls** triggered on view appear
2. **JSON parsing** executed synchronously on main thread
3. **System calls** (proxy status checks) blocking UI
4. **Service start/stop** operations in lifecycle methods

### Affected Views

| View | Issue | Severity |
|------|-------|----------|
| `GroupsView` | `.task` calls Clash API (network) | High |
| `ConfigNodeListView` | `.onAppear` parses JSON synchronously | High |
| `ConfigRuleListView` | `.onAppear` parses JSON synchronously | High |
| `SystemProxyControlView` | `.task` applies system proxy | Medium |
| `ProxyModeSettingsView` | `.task` + `.onAppear` check extension status | Medium |
| `AvailableVersionsView` | `.task` fetches GitHub releases | Low (sheet) |
| `LogView` | `.onAppear` starts log service | Low |

## Proposed Solution

### Apple HIG Compliance

Follow Apple's Human Interface Guidelines:
1. **Instant feedback** - Navigation must feel immediate
2. **Loading indicators** - Show progress for async work
3. **Cached data** - Display stale data while refreshing
4. **Background operations** - Never block the main thread

### Implementation Strategy

1. **Skip redundant loads** - Add guards to check if data is already loaded
2. **Move heavy work off main thread** - Use `Task.detached` with `.utility` priority
3. **Add loading states** - Show skeleton/progress UI during async work
4. **Preload on connection** - Load Groups/Nodes/Rules when connection establishes
5. **Debounce rapid navigation** - Use `.id()` modifier for view identity

## Scope

This change affects:
- `/Views/Groups/GroupsView.swift`
- `/Views/Nodes/ConfigNodeListView.swift`
- `/Views/Rules/ConfigRuleListView.swift`
- `/Views/Dashboard/SystemProxyControlView.swift`
- `/Views/Settings/ProxyModeSettingsView.swift`
- `/Views/DetailView.swift`

## Success Criteria

- [ ] Navigation between all panels is instant (< 16ms frame time)
- [ ] No visible lag when rapidly clicking navigation items
- [ ] No "layout recursion" warnings in console
- [ ] Loading indicators displayed during async work
- [ ] Data cached and not re-fetched on every panel visit

## Related Changes

- `fix-connection-performance` (13/16 tasks - related performance work)
- `polish-ui-apple-hig` (0/10 tasks - HIG compliance)

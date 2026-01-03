# Design: Optimize View Lifecycle Operations

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Navigation Flow                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   SidebarView ──► MainView ──► DetailView ──► Panel Views   │
│                                     │                        │
│                                     ▼                        │
│                              .id(selection)                  │
│                              (view identity)                 │
│                                                              │
│   Current Problem:                                           │
│   • Each Panel View runs .onAppear/.task on every switch    │
│   • Heavy operations block main thread                       │
│   • SwiftUI recreates views, losing cached state             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Design Principles

### 1. Instant Navigation (Apple HIG)

```swift
// ❌ BAD: Blocking on appear
.onAppear {
    let data = parseJSON() // BLOCKS main thread
}

// ✅ GOOD: Async with loading state
.task {
    guard !isLoaded else { return } // Skip if cached
    await MainActor.run { isLoading = true }
    let data = await Task.detached { parseJSON() }.value
    await MainActor.run { 
        self.data = data
        isLoading = false 
    }
}
```

### 2. Cache-First Pattern

```swift
// Check cache before loading
private func loadIfNeeded() async {
    // Skip if already loaded with same data
    guard data.isEmpty || needsRefresh else { return }
    
    // Load from preloaded cache if available
    if !preloadedData.isEmpty {
        self.data = preloadedData
        return
    }
    
    // Otherwise fetch async
    await fetchData()
}
```

### 3. Preload on Connection

```swift
// In DetailView or ConnectionService
.onChange(of: connectionService.status) { _, newStatus in
    if case .connected = newStatus {
        Task {
            // Delay to let UI settle
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // Preload all panel data in background
            await preloadNodesAndRules() // Local JSON only
            // Don't preload Groups (network call)
        }
    }
}
```

## Component Solutions

### ConfigNodeListView / ConfigRuleListView

**Problem**: `parseNodes()` / `parseRules()` execute JSON parsing on main thread

**Solution**:
1. Accept preloaded data as parameter
2. Use preloaded data if available
3. Parse in background with loading indicator if needed

```swift
struct ConfigNodeListView: View {
    var preloadedNodes: [ConfigNode] = []
    @State private var nodes: [ConfigNode] = []
    @State private var isLoading = false
    
    .onAppear {
        // Instant: use preloaded data
        if !preloadedNodes.isEmpty && nodes.isEmpty {
            nodes = preloadedNodes
        } else if nodes.isEmpty {
            // Background parse with loading
            parseNodesAsync()
        }
    }
    
    private func parseNodesAsync() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let parsed = parseNodes()
            await MainActor.run {
                nodes = parsed
                isLoading = false
            }
        }
    }
}
```

### GroupsView

**Problem**: `.task` makes network call to Clash API

**Solution**:
1. Use `.task(id:)` to only run when connection status changes
2. Add 500ms delay for Clash API to be ready
3. Skip if already loaded

```swift
.task(id: connectionStatusId) {
    guard isConnected && viewModel.groups.isEmpty else { return }
    try? await Task.sleep(nanoseconds: 500_000_000)
    await loadIfNeeded()
}
```

### SystemProxyControlView

**Problem**: `.task` applies system proxy on every appear

**Solution**:
1. Only apply if enabled AND not already applied
2. Track applied state to avoid redundant calls

```swift
@State private var hasApplied = false

.task {
    guard systemProxyEnabled && !hasApplied else { return }
    await applySystemProxy(true)
    hasApplied = true
}
```

## Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| Preloading | Instant panel switch | Memory usage, stale data |
| Lazy loading | Fresh data always | Visible loading delay |
| Background parsing | No UI block | Complexity, state sync |

**Chosen approach**: Preload + background parsing with caching
- Preload local data (Nodes/Rules) on connection
- Don't preload network data (Groups) - load on demand with delay
- Cache all data to avoid re-loading on panel switch

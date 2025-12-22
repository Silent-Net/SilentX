# Implementation Plan: Groups Panel - 代理组管理

**Feature**: 004-groups-panel  
**Created**: 2025-12-13  
**Status**: Ready for Implementation

## Tech Stack

- **UI Framework**: SwiftUI (macOS)
- **Networking**: URLSession for Clash API
- **State Management**: @Observable / ObservableObject
- **Async**: Swift Concurrency (async/await)

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        GroupsView                            │
│  ┌─────────────────┐  ┌─────────────────────────────────┐   │
│  │ GroupListView   │  │      GroupDetailView            │   │
│  │  - Group 1      │  │  ┌─────────────────────────┐    │   │
│  │  - Group 2 ◀───────│  │ GroupItemView (node)    │    │   │
│  │  - Group 3      │  │  │ GroupItemView (node)    │    │   │
│  │  ...            │  │  │ ...                     │    │   │
│  └─────────────────┘  │  └─────────────────────────┘    │   │
│                       │  [Test Latency] [Collapse/Expand]│   │
│                       └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    GroupsViewModel                           │
│  - groups: [OutboundGroup]                                  │
│  - selectedGroup: OutboundGroup?                            │
│  - loadGroups()                                             │
│  - selectNode(group:node:)                                  │
│  - testLatency(group:)                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ClashAPIClient                            │
│  - baseURL: URL (127.0.0.1:9099)                            │
│  - getProxies() -> [String: ProxyInfo]                      │
│  - selectProxy(group:node:)                                 │
│  - getDelay(proxy:url:timeout:)                             │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
SilentX/
├── Models/
│   └── OutboundGroup.swift        # Group & Item models
├── Services/
│   └── ClashAPIClient.swift       # Clash API HTTP client
├── Views/
│   ├── ContentView.swift          # Add Groups navigation
│   └── Groups/
│       ├── GroupsView.swift       # Main groups panel
│       ├── GroupListView.swift    # Left sidebar list
│       ├── GroupDetailView.swift  # Right detail panel
│       └── GroupItemView.swift    # Single node row
└── ViewModels/
    └── GroupsViewModel.swift      # Groups state management
```

## Data Models

### OutboundGroup

```swift
struct OutboundGroup: Identifiable, Hashable {
    let id = UUID()
    let tag: String           // "Hong Kong", "NodeSelected"
    let type: String          // "selector", "urltest"
    var selected: String      // Currently selected node tag
    var items: [OutboundGroupItem]
    var isExpanded: Bool = true
    
    var isSelectable: Bool { type == "selector" }
}
```

### OutboundGroupItem

```swift
struct OutboundGroupItem: Identifiable, Hashable {
    let id = UUID()
    let tag: String           // "HK-01", "JP-Tokyo"
    let type: String          // "trojan", "shadowsocks", etc.
    var delay: Int?           // Latency in ms, nil = not tested
    var isSelected: Bool
    
    var delayColor: Color {
        guard let delay else { return .gray }
        if delay < 300 { return .green }
        if delay < 600 { return .yellow }
        return .red
    }
    
    var delayText: String {
        guard let delay else { return "" }
        return "\(delay)ms"
    }
}
```

## Clash API Integration

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /proxies | Get all proxies and groups |
| GET | /proxies/:name | Get specific proxy details |
| PUT | /proxies/:name | Select node in selector group |
| GET | /proxies/:name/delay | Test node latency |

### Response Format

```json
// GET /proxies
{
  "proxies": {
    "Hong Kong": {
      "type": "Selector",
      "now": "HK-01",
      "all": ["HK-01", "HK-02", "HK-03"]
    },
    "HK-01": {
      "type": "Trojan",
      "history": [{"delay": 78}]
    }
  }
}
```

## UI Design

### GroupsView Layout

- **Left Panel (200pt)**: Scrollable list of groups
- **Right Panel (flex)**: Selected group's nodes
- **Group Row**: Icon + Name + Node Count + Type Badge
- **Node Row**: Radio/Check + Name + Type + Delay

### Color Coding

| Delay | Color | Meaning |
|-------|-------|---------|
| < 300ms | Green | Fast |
| 300-600ms | Yellow | Medium |
| > 600ms | Red | Slow |
| N/A | Gray | Not tested |

## State Flow

```
App Launch
    │
    ▼
ConnectionService.connect()
    │
    ▼
GroupsViewModel.loadGroups() ◄─── Trigger on connect
    │
    ▼
ClashAPIClient.getProxies()
    │
    ▼
Parse & Update groups array
    │
    ▼
UI Renders GroupsView
```

## Integration Points

1. **Sidebar Navigation**: Add "Groups" item after "Overview"
2. **Connection Status**: Disable Groups when disconnected
3. **Config Parsing**: Extract Clash API port from profile config

## Risk Mitigation

- **Clash API not enabled**: Check config and show helpful error
- **API timeout**: 5s timeout with retry option
- **Large node lists**: Lazy loading / virtualization for 100+ nodes

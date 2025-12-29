# improve-nodes-groups-ui

## Summary
Improve UI aesthetics for Nodes and Groups panels to be cleaner and more professional.

## Status
- [x] Proposal created
- [ ] Approved
- [ ] Implemented
- [ ] Deployed
- [ ] Archived

## Current Problems

### 1. Nodes Panel - Colorful Protocol Badges
The protocol type badges (TROJAN, VMESS, etc.) use colored backgrounds that look cluttered and unprofessional:

**Current implementation** (`ConfigNodeRowView` line 183-197):
```swift
Text(node.type.uppercased())
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(typeColor.opacity(0.15))  // Colored background
    .foregroundStyle(typeColor)            // Colored text
    .cornerRadius(4)
```

### 2. Groups Panel - Header Text Wrapping
The group detail header has too many elements in a horizontal layout, causing text to wrap on two lines when space is limited:

**Current layout** (`GroupDetailView` header line 58-79):
```
[Selector] · [5 nodes] · [✓ Hong Kong]  ← All on one HStack, wraps badly
```

The third image shows "Selec-tor" and "5 nodes" wrapping to two lines.

## Proposed Changes

### 1. Nodes Panel - Simple Gray Protocol Text
Replace colorful badges with clean, monochrome protocol labels:
- Use `.secondary` color for all protocols
- Remove colored backgrounds
- Keep text uppercase but without visual noise

### 2. Groups Panel - Responsive Layout
Redesign header to handle space better:
- Stack information vertically when needed
- Remove redundant separators
- Show selected node on its own line if needed

## Scope
- `ConfigNodeRowView` in `ConfigNodeListView.swift`
- `GroupDetailView.swift` header section

## Related Files
- `SilentX/Views/Nodes/ConfigNodeListView.swift` (lines 172-217)
- `SilentX/Views/Groups/GroupDetailView.swift` (lines 46-80)

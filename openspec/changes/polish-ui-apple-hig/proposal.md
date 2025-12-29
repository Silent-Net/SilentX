# polish-ui-apple-hig

## Summary
Polish SilentX UI to strictly follow Apple Human Interface Guidelines and add modern "Liquid Glass" visual effects for a premium, native macOS feel.

## Status
- [x] Proposal created
- [ ] Approved
- [ ] Implemented
- [ ] Deployed

## Apple HIG Core Principles
Per Apple's Human Interface Guidelines:
- **Clarity**: Legible text, precise icons, easy navigation
- **Deference**: UI supports content, doesn't compete with it
- **Depth**: Visual layers, vibrancy, and blur create hierarchy

## Current Issues
- Solid opaque backgrounds feel dated
- Missing vibrancy/translucency effects
- Cards/panels don't have glass-like depth
- No subtle shadows or light effects

## Proposed Enhancements

### 1. Glass Material Backgrounds
Apply SwiftUI material backgrounds to key UI sections:
```swift
// Dashboard connection section
.background(.regularMaterial)
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
```

Materials available:
- `.ultraThinMaterial` - Maximum translucency
- `.thinMaterial` - Light translucency
- `.regularMaterial` - Standard glass effect
- `.thickMaterial` - Stronger blur

### 2. Visual Depth Hierarchy
Add subtle shadows to floating elements:
```swift
.shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
```

### 3. Vibrancy for Text/Icons
Use semantic colors that adapt to glass backgrounds:
```swift
.foregroundStyle(.primary)  // Vibrant text on glass
.foregroundStyle(.secondary)
```

### 4. Connection Status Card
Redesign with glass treatment:
- Frosted glass background
- Subtle inner glow when connected
- Smooth gradient transitions

### 5. Sidebar Enhancement
Apply glass effect to sidebar for depth:
```swift
.background(.sidebar)  // System sidebar material
```

## Files to Modify
- `Views/Dashboard/DashboardView.swift` - Glass backgrounds
- `Views/Dashboard/ConnectionStatusView.swift` - Status card polish
- `Views/Dashboard/ModeSwitcherView.swift` - Segmented control styling
- `Views/Dashboard/ProfileSelectorView.swift` - Dropdown styling
- `Views/Dashboard/SystemProxyControlView.swift` - Toggle card
- `Views/SidebarView.swift` - Sidebar vibrancy
- `Views/Groups/GroupDetailView.swift` - Header polish

## Reference
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- macOS Tahoe Liquid Glass: Real-time blur, translucent materials

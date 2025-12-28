# Fix Connection Performance

## Summary
Optimize connect/disconnect speed to match SFM performance and fix UI animation bug where the status dot flies in from the bottom-left corner on app launch.

## Problem Analysis

### Issue 1: Slow Connect/Disconnect
**Current behavior:** Connecting and disconnecting takes noticeable time with visible "Connecting..." and "Disconnecting..." states.

**Expected behavior (SFM):** Instant response - connect/disconnect happens immediately without visible delay.

**Root causes identified:**
1. `PrivilegedHelperEngine.start()` has a 200ms `Task.sleep` after sending start command (line 118)
2. The verification step (`ipcClient.status()`) after start adds latency
3. UI shows transitioning states that may be unnecessary for fast operations

### Issue 2: Status Dot Animation Bug
**Current behavior:** On app launch, the green status dot animates from the bottom-left corner to its correct position.

**Root cause:** In `StatusIndicator` (ConnectionStatusView.swift):
- Uses `@State private var isAnimating = false`
- `.onAppear { isAnimating = true }`
- Combined with `.animation()` modifier

**SwiftUI mechanism:** When a view first appears, SwiftUI may animate *all* animatable properties if an `.animation()` modifier is present. The initial layout position (0,0 or default) gets animated to the final position. This is called "implicit animation leaking" - the animation modifier affects unintended properties during the first layout pass.

## Proposed Solution

### Connection Speed
1. Remove the 200ms delay - trust service response directly
2. Make status verification optional (only on error)
3. Use optimistic UI updates - show connected immediately on success response

### Animation Bug
1. Use `animation(_:value:)` instead of implicit `.animation()` to scope animation only to specific values
2. Or use `.transaction { $0.animation = nil }` on appear to prevent initial animation
3. Or initialize `@State` with final animation state

## Affected Files
- `SilentX/Services/Engines/PrivilegedHelperEngine.swift`
- `SilentX/Views/Dashboard/ConnectionStatusView.swift`

## Priority
High - this is user-facing performance issue affecting daily use.

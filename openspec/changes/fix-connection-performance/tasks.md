# Tasks: Fix Connection Performance

## 1. Fix Status Indicator Animation Bug
- [x] 1.1 In `StatusIndicator`, replaced implicit `.animation()` with explicit `animation(_:value:)` scoped to `status.isTransitioning`
- [x] 1.2 Initialize `isAnimating = true` directly to prevent initial animation
- [ ] 1.3 Test that dot no longer flies in from corner on launch

## 2. Optimize Connection Speed (App Side)
- [x] 2.1 Removed the 200ms `Task.sleep` delay in `PrivilegedHelperEngine.start()`
- [x] 2.2 Trust the service response directly - if start returns PID, consider it connected
- [x] 2.3 **Removed `preflightSingBoxCheck()`** - was running `sing-box check` adding 1-2 seconds delay

## 3. Optimize Service CoreManager Delays
- [x] 3.1 Reduced config switch wait: 500ms → 100ms
- [x] 3.2 Reduced crash verify wait: 500ms → 100ms
- [x] 3.3 Reduced graceful shutdown: 3s → 1s max
- [x] 3.4 Skip synchronous TUN release wait on disconnect (done by next connect if needed)

## 4. Additional Fixes
- [x] 4.1 Translated "重连" to "Reconnect"
- [x] 4.2 Translated all Chinese in ErrorRecoveryView to English

## 5. Verification
- [x] 5.1 Build succeeded (SilentX app)
- [x] 5.2 Build succeeded (SilentX-Service)
- [ ] 5.3 Verify connect/disconnect is instant like SFM
- [ ] 5.4 Verify status dot appears in correct position on launch

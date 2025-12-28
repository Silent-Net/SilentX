# Tasks

## Investigation Phase

- [x] **1. Debug Discord failure with failure.json**
  - **ROOT CAUSE FOUND**: `restoreOriginalSettings()` only restored HTTP/HTTPS proxy, not SOCKS proxy
  - When switching from port 2088 config to port 2080 config (TapFog), stale SOCKS port 2088 remained
  - Discord uses SOCKS proxy and failed connecting to wrong port (2088 instead of 2080)
  - **FIX**: Added `setSOCKSProxy(..., enable: false)` to `restoreOriginalSettings()`
  
- [ ] **2. Verify SystemProxyService actually modifies macOS settings**
  - Run `scutil --proxy` before and after toggle to confirm changes
  - Check if commands require sudo or specific entitlements
  - Test if networksetup commands are actually executed

## Implementation Phase

- [x] **3. Fix "Manage Profiles..." navigation**
  - Added onManageProfiles closure to ProfileSelectorView
  - Added navigation binding chain: MainView → DetailView → DashboardView → ProfileSelectorView
  
- [x] **4. Add System Proxy state memory**
  - Changed `@State` to `@AppStorage("systemProxyEnabled")` in SystemProxyControlView
  - Toggle state now persists across reconnects and app launches

- [x] **5. Fix SystemProxyService to actually affect macOS**
  - Implemented ConnectionService.setSystemProxy() to call SystemProxyService.enableProxy/restoreOriginalSettings
  - Now properly enables/disables HTTP, HTTPS, and SOCKS proxies via networksetup

## Validation Phase

- [ ] **6. Test Discord with multiple config variants**
  - Test with port 9090/2080 (failure.json style)
  - Test with port 9099/2088 (correct.json style)
  - Test with mixed ports

- [ ] **7. Verify System Proxy integration**
  - Toggle ON → check System Preferences shows proxy
  - Toggle OFF → check System Preferences shows no proxy
  - Reconnect → verify toggle remembers state

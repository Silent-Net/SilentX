# fix-system-proxy-and-navigation

## Summary
This change addresses three critical issues reported by the user:
1. **Discord not working with certain configs** - failure.json doesn't work while correct.json does
2. **"Manage Profiles..." navigation not working** - Button in Dashboard dropdown doesn't navigate to Profiles tab
3. **System Proxy state issues** - Toggle doesn't remember state across reconnects and doesn't actually affect macOS system proxy settings

## Status
- [x] Proposal created
- [ ] Approved
- [ ] Implemented
- [ ] Deployed
- [ ] Archived

## Problem Analysis

### Issue 1: Discord Config Incompatibility
- `correct.json` (port 9099/2088) works with Discord
- `failure.json` (port 9090/2080) does NOT work with Discord
- Same config works in SFM but not in SilentX
- Groups panel shows data now, but Discord still fails
- **Suspected**: Additional hardcoded behavior or DNS/routing difference

### Issue 2: Manage Profiles Navigation
- Dashboard shows "Manage Profiles..." button in profile selector dropdown
- Clicking it does nothing - no navigation to Profiles tab
- User expects this to navigate to Profiles page

### Issue 3: System Proxy State Issues
- Toggle doesn't remember user's preference across reconnects
- Toggle always resets to OFF when reconnecting
- **Critical**: Toggle changes don't actually affect macOS System Preferences → Network → Proxies
- User verified by checking System Preferences - proxy settings don't change when toggle is used

## Scope
- Investigate and fix Discord compatibility with different port configurations
- Implement "Manage Profiles..." navigation action
- Add AppStorage for System Proxy state memory
- Fix SystemProxyService to actually modify macOS proxy settings

## Related Files
- `SilentX/Views/Dashboard/ProfileSelectorView.swift` - Manage Profiles button
- `SilentX/Views/Dashboard/SystemProxyControlView.swift` - System Proxy toggle
- `SilentX/Services/SystemProxyService.swift` - macOS proxy integration
- `SilentX/Services/ConnectionService.swift` - Port configuration logic

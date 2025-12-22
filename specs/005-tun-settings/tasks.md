# Tasks: TUN Interface Settings - TUN接口自定义配置

**Input**: spec.md, plan.md
**Feature**: 005-tun-settings

---

## Phase 1: Data Model & Storage

- [ ] T001 Create TUNSettings.swift with TUNPreset enum and TUNSettings struct in `SilentX/Models/TUNSettings.swift`
- [ ] T002 [P] Add tunSettingsKey constant in `SilentX/Shared/Constants.swift`

**Checkpoint**: Data model ready

---

## Phase 2: Settings UI

- [ ] T003 Create TUNSettingsView with preset picker and text fields in `SilentX/Views/Settings/TUNSettingsView.swift`
- [ ] T004 [P] Create TUNSettingsValidator for input validation in `SilentX/Services/TUNSettingsValidator.swift`
- [ ] T005 Integrate TUNSettingsView into ProxyModeSettingsView in `SilentX/Views/Settings/ProxyModeSettingsView.swift`

**Checkpoint**: UI complete, validation working

---

## Phase 3: Config Transformation

- [ ] T006 Implement applyTUNSettings() method in `SilentX/Services/ConnectionService.swift`
- [ ] T007 Update connect() flow to call applyTUNSettings() before writing config in `SilentX/Services/ConnectionService.swift`

**Checkpoint**: Config transformation working

---

## Phase 4: Testing & Polish

- [ ] T008 Test preset switching and custom configuration
- [ ] T009 Update config2-port-2088.json with non-conflicting defaults in `RefRepo/config2-port-2088.json`
- [ ] T010 Run xcodebuild to verify no compile errors

---

## Dependencies

```
T001 ─┬─► T003 ─► T005
      │
T002 ─┘
      
T004 ─► T003

T001 ─► T006 ─► T007
```

## Summary

| Phase | Tasks | Parallel |
|-------|-------|----------|
| Phase 1 | 2 | T001, T002 can run parallel |
| Phase 2 | 3 | T003 depends on T001, T004 |
| Phase 3 | 2 | Sequential |
| Phase 4 | 3 | Sequential |
| **Total** | **10** | |

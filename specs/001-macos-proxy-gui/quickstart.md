# SilentX Quickstart Guide

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)  
**Target**: macOS 14.0+ (Sonoma)

This guide helps you get SilentX running for development.

---

## Prerequisites

### Required Software

| Tool | Version | Check Command |
|------|---------|---------------|
| Xcode | 15.0+ | `xcodebuild -version` |
| macOS | 14.0+ (Sonoma) | `sw_vers` |
| Git | 2.x | `git --version` |

### Apple Developer Account

For **GUI development only**: Free Apple ID works fine.

For **Network Extension development** (Phase 3):
- Paid Apple Developer Program membership required
- You'll need to provision entitlements

---

## Project Setup

### 1. Clone and Initialize

```bash
# Navigate to workspace
cd /Users/xmx/workspace/Silent-Net/SilentX

# Verify you're on the feature branch
git branch
# Should show: * 001-macos-proxy-gui
```

### 2. Open in Xcode

```bash
open SilentX.xcodeproj
```

Or use VS Code with Swift extension for code editing, switching to Xcode for running.

### 3. Set Development Team

1. Select **SilentX** project in navigator
2. Go to **Signing & Capabilities** tab
3. Select your Apple ID team under **Team**
4. Let Xcode manage signing automatically

---

## Project Structure (Target)

```
SilentX/
├── SilentX/                    # Main app target
│   ├── SilentXApp.swift        # @main entry point
│   ├── ContentView.swift       # Root view (will become MainView)
│   ├── Views/
│   │   ├── Sidebar/
│   │   ├── Dashboard/
│   │   ├── Profiles/
│   │   ├── Nodes/
│   │   ├── Rules/
│   │   └── Settings/
│   ├── Models/                 # SwiftData models
│   ├── Services/               # Business logic
│   └── Assets.xcassets
├── Shared/                     # Shared framework (future)
├── SilentXExtension/           # Network Extension (Phase 3)
├── SilentXTests/
└── SilentXUITests/
```

---

## Development Workflow

### Pre-commit Validation

**Constitution Requirement**: All commits must pass build validation (Section VII).

```bash
# Install pre-commit hook (run once)
cp .specify/scripts/bash/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**What it checks:**
- Build succeeds (`xcodebuild build -scheme SilentX`)
- No compilation errors
- Tests pass (optional, uncomment in hook)

**Bypass** (discouraged): `git commit --no-verify`

### Build and Run

**Keyboard shortcuts:**
- `⌘R` - Build and Run
- `⌘B` - Build only
- `⌘.` - Stop running app
- `⌘⇧K` - Clean build folder

### SwiftUI Previews

Use Canvas previews for rapid UI iteration:

1. Open a view file (e.g., `ContentView.swift`)
2. Press `⌥⌘↩` to show/hide Canvas
3. Press `⌥⌘P` to resume preview

**Preview Provider Example:**

```swift
struct MyView: View {
    var body: some View {
        Text("Hello")
    }
}

#Preview {
    MyView()
}
```

### Hot Reload

SwiftUI previews update automatically. For running app:
- Changes to View bodies often hot-reload
- Model/logic changes require restart

---

## MVP Development Phases

### Phase 1: GUI Foundation (Current)

**Focus**: Build complete UI with mock data

```swift
// Use in-memory SwiftData container for development
@main
struct SilentXApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Profile.self, ProxyNode.self, RoutingRule.self], 
                               inMemory: true) // Mock data mode
        }
    }
}
```

**Week 1-2 Tasks:**
- [ ] Set up NavigationSplitView shell
- [ ] Create SwiftData models
- [ ] Build Sidebar navigation
- [ ] Create Profile list view

### Phase 2: Core Integration

**Focus**: Integrate Sing-Box binary, configuration generation

### Phase 3: Network Extension

**Focus**: Add VPN connectivity (requires Apple Developer account)

### Phase 4: Polish

**Focus**: Performance optimization, error handling, App Store prep

---

## Testing

### Unit Tests

```bash
# Run all tests
xcodebuild test -scheme SilentX -destination 'platform=macOS'

# Or use Xcode: ⌘U
```

### UI Tests

```bash
xcodebuild test -scheme SilentX -destination 'platform=macOS' \
  -only-testing:SilentXUITests
```

### Performance Testing

**Constitution Targets** (Section III):
- Launch: <3s (cold start from Dock/Spotlight)
- Connect: <5s (from button press to status=connected)
- Validation: <1s (JSON schema check)
- Core switch: <10s (excluding download)

**Measurement Methodology:**
```bash
# Run performance suite
xcodebuild test -scheme SilentX -destination 'platform=macOS' \
  -only-testing:SilentXUITests/PerformanceMetricsTests
```

**How metrics are captured:**
- Launch: `XCTApplicationLaunchMetric` from cold start
- Connect: Custom `os_signpost` interval in ConnectionService
- Validation: `Benchmark` in ConfigurationService
- Core switch: Process spawn timing in CoreVersionService

**Fail conditions**: Any metric exceeding threshold fails CI.

### Preview Testing

For SwiftUI, previews ARE your tests during development. Create previews for:
- Empty states
- Loaded states with sample data
- Error states

```swift
#Preview("Empty State") {
    ProfileListView()
        .modelContainer(for: Profile.self, inMemory: true)
}

#Preview("With Profiles") {
    ProfileListView()
        .modelContainer(previewContainer)
}
```

---

## Common Tasks

### Add a New View

1. Create file in appropriate `Views/` subfolder
2. Define SwiftUI View struct
3. Add preview at bottom
4. Import in parent view

### Add a SwiftData Model

1. Create file in `Models/`
2. Use `@Model` macro
3. Add to `modelContainer` in App
4. Run migration (automatic for dev)

### Debug SwiftData

```swift
// Print all profiles
let profiles = try context.fetch(FetchDescriptor<Profile>())
print(profiles)
```

---

## Resources

### Apple Documentation
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)

### Reference Implementation
- SFM source: `/Users/xmx/workspace/Silent-Net/RefRepo/sing-box-for-apple/`
- Key files:
  - `MacLibrary/MainView.swift` - Navigation structure
  - `Library/Database/Profile.swift` - Profile model (GRDB, not SwiftData)

### Sing-Box
- [sing-box Documentation](https://sing-box.sagernet.org/)
- Core source: `/Users/xmx/workspace/Silent-Net/RefRepo/sing-box/`

---

## Troubleshooting

### "Cannot preview in this file"

- Ensure `#Preview` macro syntax is correct
- Check for compilation errors in the file
- Restart Xcode preview (⌥⌘P)

### SwiftData migration errors

During development, use in-memory containers to avoid migration issues:

```swift
.modelContainer(for: Schema.self, inMemory: true)
```

### Build fails after model changes

```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/SilentX-*
```

### Preview crashes

Check Console.app for crash logs. Common causes:
- Missing `@Environment` values
- Nil model relationships

---

---

## Phase 2 Implementation Summary: GitHub Releases API

**Status**: ✅ Complete  
**Date**: 2025-12-06

### What Was Built

Implemented **real-time GitHub Releases API integration** for Core Version Management:

1. **GitHubReleaseService** (NEW)
   - File: `SilentX/Services/GitHubReleaseService.swift` (300+ lines)
   - Fetches real sing-box releases from https://api.github.com/repos/SagerNet/sing-box/releases
   - Methods: `fetchReleases(page:)`, `fetchLatestRelease()`, `fetchReleaseByTag(_:)`
   - Rate limit detection (60 req/hr without auth)
   - Mock implementation for testing

2. **Enhanced CoreVersionService**
   - File: `SilentX/Services/CoreVersionService.swift`
   - Dependency injection: `init(githubService: GitHubReleaseServiceProtocol)`
   - `fetchAvailableReleases()` now calls real API instead of mock data

3. **Enhanced Error Handling**
   - File: `SilentX/Services/CoreVersionError.swift`
   - New cases: `rateLimitExceeded(resetTime:)`, `networkError(statusCode:)`, `decodingFailed(_:)`
   - User-friendly messages with recovery suggestions

### Testing

**Manual Test:**
1. Run app: `⌘R`
2. Navigate to **Settings → Core Versions**
3. Click refresh button
4. Should show real releases: v1.9.0, v1.8.14, etc.

**Expected Output:**
```
Core Versions Tab:
- v1.9.0 (Released Nov 29, 2025)  ← Real GitHub data
- v1.8.14 (Released Nov 6, 2025)  ← Real GitHub data
[Refresh Button] ← Fetches live data
```

### Architecture

```
CoreVersionsView
       ↓
CoreVersionService (@ObservableObject)
       ↓
GitHubReleaseServiceProtocol
       ↓
URLSession → GitHub API
```

**Dependency Injection:**
- Production: `CoreVersionService(githubService: GitHubReleaseService())`
- Testing: `CoreVersionService(githubService: MockGitHubReleaseService())`

### Documentation Generated

- [research.md](research.md) - Section 8: GitHub API investigation
- [data-model.md](data-model.md) - CoreVersion, Release, ReleaseAsset schemas
- [contracts/github-release-service.md](contracts/github-release-service.md) - API contract
- [contracts/core-version-service.md](contracts/core-version-service.md) - Service contract

### Build Validation

**Xcode**:
```
⌘B  # Build
✓ Build Succeeded
```

### Next Implementation Steps

#### Phase 2b: Download Functionality (Future)
1. Implement `downloadVersion(_ release:)` with URLSession.downloadTask
2. Add SHA256 checksum verification using CryptoKit
3. Extract tar.gz archives
4. Save binaries to Application Support directory

#### Phase 2c: Version Switching (Future)
1. Persist downloaded versions with SwiftData
2. Implement `switchToVersion(_:)`
3. Update active version indicator in UI

#### Phase 2d: Auto-Update (Future)
1. Background check for new releases (24h interval)
2. Notification when new version available
3. Optional GitHub token for higher rate limits (5000/hr)

---

## Next Steps

After reading this guide:

1. **Run the existing app** - `⌘R` to verify setup works
2. **Test GitHub API** - Navigate to Settings → Core Versions, click refresh
3. **Create your first view** - Start with `SidebarView.swift` (if needed)
4. **Add SwiftData models** - Create `Profile.swift` in Models folder (if needed)
5. **Follow the tasks** - See `tasks.md` (generated next) for detailed steps

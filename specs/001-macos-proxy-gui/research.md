# Research: SilentX - macOS Proxy Tool

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)  
**Date**: December 6, 2025  
**Updated**: December 6, 2025 (Added GitHub Releases API Integration)

## Executive Summary

This document consolidates research findings for building SilentX, a user-friendly macOS proxy tool based on Sing-Box. Key decisions cover SwiftUI architecture, SwiftData persistence, Network Extension integration, development workflow, and **GitHub Releases API integration for real-time core version management**.

---

## 1. SwiftUI Development Workflow for macOS

### Decision: Use Xcode with SwiftUI Previews for Iterative Development

**Rationale**: SwiftUI Previews enable real-time UI iteration without full app compilation. This accelerates learning and matches the user's goal of "get an app compiled and running first, then continuously make adjustments."

**Alternatives Considered**:
- UIKit/AppKit approach: Rejected - steeper learning curve, not declarative
- Third-party UI frameworks: Rejected - SwiftUI is native and best documented

### SwiftUI macOS App Structure

```swift
// Entry point: SilentXApp.swift
import SwiftUI
import SwiftData

@main
struct SilentXApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: [Profile.self, ProxyNode.self, RoutingRule.self])
    }
}
```

### Development Iteration Pattern

1. **Create View**: Define a SwiftUI View struct
2. **Add Preview**: Use `#Preview` macro for real-time visualization
3. **Test with Mock Data**: Create preview containers with sample data
4. **Refine**: Adjust layout, state management, navigation
5. **Integrate**: Connect to real data and services

---

## 2. NavigationSplitView Architecture

### Decision: Two-Column NavigationSplitView with Sidebar

**Rationale**: Matches macOS conventions (Finder, Mail, SFM), provides clear navigation hierarchy, well-documented by Apple, and simpler than three-column layout for initial implementation.

**Implementation Pattern**:

```swift
struct MainView: View {
    @State private var selection: NavigationItem? = .dashboard
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            DetailView(selection: selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### Sidebar Navigation Items

```swift
enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case profiles = "Profiles"
    case nodes = "Nodes"
    case rules = "Rules"
    case logs = "Logs"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .profiles: return "doc.text"
        case .nodes: return "server.rack"
        case .rules: return "arrow.triangle.branch"
        case .logs: return "text.alignleft"
        case .settings: return "gearshape"
        }
    }
}
```

---

## 3. SwiftData Persistence

### Decision: SwiftData with @Model Macro

**Rationale**: Native SwiftUI integration, automatic change tracking, simpler than GRDB (which SFM uses), Apple's recommended approach for new projects targeting macOS 14+.

### Model Definitions

```swift
import SwiftData

@Model
class Profile {
    @Attribute(.unique) var id: UUID
    var name: String
    var order: Int
    var type: ProfileType
    var configurationJSON: String
    var remoteURL: String?
    var autoUpdate: Bool
    var autoUpdateInterval: Int // hours
    var lastUpdated: Date?
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \ProxyNode.profile)
    var nodes: [ProxyNode]
    
    @Relationship(deleteRule: .cascade, inverse: \RoutingRule.profile)
    var rules: [RoutingRule]
    
    init(name: String, type: ProfileType = .local) {
        self.id = UUID()
        self.name = name
        self.order = 0
        self.type = type
        self.configurationJSON = "{}"
        self.autoUpdate = false
        self.autoUpdateInterval = 24
        self.createdAt = Date()
    }
}

enum ProfileType: Int, Codable {
    case local = 0
    case remote = 1
    case icloud = 2
}

@Model
class ProxyNode {
    @Attribute(.unique) var id: UUID
    var name: String
    var serverAddress: String
    var port: Int
    var protocolType: ProxyProtocol
    var credentials: Data? // Encrypted JSON
    var order: Int
    var isEnabled: Bool
    var latency: Int? // milliseconds, nil = not tested
    
    var profile: Profile?
    
    init(name: String, serverAddress: String, port: Int, protocolType: ProxyProtocol) {
        self.id = UUID()
        self.name = name
        self.serverAddress = serverAddress
        self.port = port
        self.protocolType = protocolType
        self.order = 0
        self.isEnabled = true
    }
}

enum ProxyProtocol: String, Codable, CaseIterable {
    case shadowsocks = "shadowsocks"
    case vmess = "vmess"
    case vless = "vless"
    case trojan = "trojan"
    case hysteria2 = "hysteria2"
    case http = "http"
    case socks5 = "socks5"
}

@Model
class RoutingRule {
    @Attribute(.unique) var id: UUID
    var name: String
    var matchType: RuleMatchType
    var matchValue: String
    var action: RuleAction
    var order: Int
    var isEnabled: Bool
    
    var profile: Profile?
    
    init(name: String, matchType: RuleMatchType, matchValue: String, action: RuleAction) {
        self.id = UUID()
        self.name = name
        self.matchType = matchType
        self.matchValue = matchValue
        self.action = action
        self.order = 0
        self.isEnabled = true
    }
}

enum RuleMatchType: String, Codable, CaseIterable {
    case domain = "domain"
    case domainSuffix = "domain_suffix"
    case domainKeyword = "domain_keyword"
    case ipCIDR = "ip_cidr"
    case geoIP = "geoip"
    case process = "process_name"
}

enum RuleAction: String, Codable, CaseIterable {
    case proxy = "proxy"
    case direct = "direct"
    case block = "reject"
}

@Model
class CoreVersion {
    @Attribute(.unique) var version: String
    var downloadURL: String
    var localPath: String?
    var downloadDate: Date?
    var isActive: Bool
    var fileHash: String?
    
    init(version: String, downloadURL: String) {
        self.version = version
        self.downloadURL = downloadURL
        self.isActive = false
    }
}
```

### SwiftData Container Setup

```swift
@main
struct SilentXApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Profile.self,
            ProxyNode.self,
            RoutingRule.self,
            CoreVersion.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

---

## 4. Network Extension Integration

### Decision: Phased Integration - GUI First, Network Extension Later

**Rationale**: Network Extension requires Apple Developer account with special entitlements, code signing, and System Extension approval. Building the UI first allows learning SwiftUI without these complications.

### SFM Architecture Reference

SFM uses a multi-target structure:
- **SFM**: Main application (SwiftUI)
- **Extension**: Network Extension (NEPacketTunnelProvider)
- **SystemExtension**: System Extension for macOS (standalone daemon)

Key components from SFM:
- `ExtensionProvider.swift`: NEPacketTunnelProvider subclass
- `ExtensionProfile.swift`: NETunnelProviderManager wrapper
- `SystemExtension.swift`: OSSystemExtensionRequest handler
- `CommandClient.swift`: IPC between app and extension

### MVP Phase (No Network Extension)

For initial development without Network Extension:
1. Build complete UI with SwiftUI
2. Implement profile/node/rule management with SwiftData
3. Use mock connection status
4. Add JSON import/export functionality

### Post-MVP Phase (Network Extension)

1. Apply for Network Extension entitlements from Apple
2. Create Extension target with NEPacketTunnelProvider
3. Integrate Libbox (Sing-Box Go library)
4. Implement IPC between main app and extension

---

## 5. SFM Architecture Analysis & Improvements

### SFM Strengths (to preserve)
- Clean NavigationSplitView structure
- Robust Network Extension handling
- Profile auto-update mechanism
- Log streaming via CommandServer

### SFM Weaknesses (to improve)

| Issue | SFM Approach | SilentX Improvement |
|-------|--------------|---------------------|
| Data persistence | GRDB (complex setup) | SwiftData (native, simpler) |
| Node editing | JSON only | GUI forms + JSON |
| Rule editing | JSON only | Drag-drop GUI + JSON |
| Core version | Single bundled | Version manager with updates |
| Error messages | Technical | User-friendly with suggestions |
| Onboarding | None | Welcome flow for first launch |

### Improved UX Patterns

1. **First Launch Experience**
   ```swift
   struct WelcomeView: View {
       @State private var step: WelcomeStep = .intro
       
       var body: some View {
           VStack {
               switch step {
               case .intro: IntroView(onNext: { step = .importProfile })
               case .importProfile: ImportOptionsView(onNext: { step = .complete })
               case .complete: ReadyView()
               }
           }
       }
   }
   ```

2. **Visual Node Editor**
   - Form-based input with validation
   - Protocol-specific fields that appear/hide dynamically
   - Latency test button with visual feedback

3. **Rule Builder**
   - Drag-and-drop reordering
   - Visual rule preview
   - One-click common rule templates

---

## 6. Logging & Observability

### Decision: Built-in Log Viewer with OSLog Integration

**Rationale**: OSLog is Apple's recommended logging framework, integrates with Console.app, and supports filtering/streaming.

### Implementation Pattern

```swift
import OSLog

extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier!
    
    static let connection = Logger(subsystem: subsystem, category: "connection")
    static let profile = Logger(subsystem: subsystem, category: "profile")
    static let core = Logger(subsystem: subsystem, category: "core")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}

// Usage
Logger.connection.info("Connecting to \(serverAddress)")
Logger.connection.error("Connection failed: \(error.localizedDescription)")
```

### Log Viewer UI

```swift
struct LogView: View {
    @State private var logs: [LogEntry] = []
    @State private var filterLevel: LogLevel = .all
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            HStack {
                Picker("Level", selection: $filterLevel) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Button("Export") { exportLogs() }
            }
            .padding()
            
            List(filteredLogs) { entry in
                LogEntryRow(entry: entry)
            }
        }
    }
}
```

---

## 7. JSON Configuration Handling

### Decision: Codable Models + JSONSerialization for Flexibility

**Rationale**: Need to both parse/generate Sing-Box configs and allow raw editing. Use Codable for type-safe operations, JSONSerialization for pass-through editing.

### Sing-Box Config Structure (subset)

```swift
struct SingBoxConfig: Codable {
    var log: LogConfig?
    var dns: DNSConfig?
    var inbounds: [Inbound]?
    var outbounds: [Outbound]
    var route: RouteConfig?
    var experimental: ExperimentalConfig?
}

struct Outbound: Codable {
    var type: String
    var tag: String
    var server: String?
    var serverPort: Int?
    // Protocol-specific fields...
    
    enum CodingKeys: String, CodingKey {
        case type, tag, server
        case serverPort = "server_port"
    }
}
```

### Configuration Service

```swift
class ConfigurationService {
    func generateConfig(from profile: Profile) throws -> String {
        // Build SingBoxConfig from Profile's nodes and rules
        // Return formatted JSON string
    }
    
    func validate(json: String) -> ValidationResult {
        // Parse and validate against Sing-Box schema
        // Return errors with line numbers for editor highlighting
    }
    
    func parseNodes(from json: String) -> [ProxyNode] {
        // Extract outbounds from JSON and convert to ProxyNode models
    }
}
```

---

## 8. File & Directory Structure

### Application Support Directory

```
~/Library/Application Support/SilentX/
├── profiles/           # Profile JSON files
│   ├── {uuid}.json
│   └── ...
├── cores/              # Cached Sing-Box binaries
│   ├── 1.10.0/
│   │   └── sing-box
│   └── 1.9.7/
│       └── sing-box
├── logs/               # Exported logs
└── SilentX.sqlite      # SwiftData database
```

### FilePath Constants

```swift
enum FilePath {
    static let applicationSupport: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SilentX", isDirectory: true)
    }()
    
    static let profiles = applicationSupport.appendingPathComponent("profiles", isDirectory: true)
    static let cores = applicationSupport.appendingPathComponent("cores", isDirectory: true)
    static let logs = applicationSupport.appendingPathComponent("logs", isDirectory: true)
}
```

---

## 9. Development Phases

### Phase 1: GUI Foundation (Current MVP)

**Goal**: Working app with UI, no proxy functionality

1. Project setup with SwiftUI + SwiftData
2. NavigationSplitView with sidebar
3. Dashboard view (placeholder)
4. Profile list and detail views
5. Node management CRUD forms
6. Rule management with drag-drop
7. Settings view
8. Log viewer (placeholder data)

**Deliverable**: App that can manage profiles/nodes/rules, import/export JSON, but cannot actually proxy traffic.

### Phase 2: Core Integration

**Goal**: Working proxy via Sing-Box

1. Integrate Libbox framework
2. JSON config generation from models
3. Local process management (non-VPN mode for testing)
4. Basic connection status

### Phase 3: Network Extension

**Goal**: Full VPN-mode proxy

1. Apply for Apple entitlements
2. Create Network Extension target
3. Implement NEPacketTunnelProvider
4. IPC between app and extension
5. System Extension for macOS

### Phase 4: Polish

**Goal**: Feature complete

1. Core version manager
2. Profile auto-update
3. Menu bar extra
4. Onboarding flow
5. Error handling improvements
6. Performance optimization

---

## 10. Testing Strategy

### Unit Tests

- Model validation logic
- JSON parsing/generation
- Rule matching logic

### UI Tests

- Navigation flows
- Form validation
- Import/export workflows

### Integration Tests (Post Phase 2)

- Profile creation → connection
- Node latency testing
- Rule evaluation

---

## 8. GitHub Releases API Integration for Core Version Management

### Problem Statement

The current Core Versions view (Settings → Core Versions tab) shows mock/hardcoded version data. Users need:
- **Real-time version discovery** from https://github.com/SagerNet/sing-box/releases
- **Automatic detection** of new releases
- **Download capability** for specific versions with asset selection
- **Version switching** between downloaded cores

### Decision: Use GitHub REST API with URLSession

**Rationale**: GitHub's REST API provides reliable, structured access to release data without authentication for public repositories.

**Base URL**: `https://api.github.com/repos/SagerNet/sing-box/releases`

**Key Endpoints**:
1. **List Releases**: `GET /repos/{owner}/{repo}/releases` - Returns all releases (paginated, max 100/page)
2. **Get Latest**: `GET /repos/{owner}/{repo}/releases/latest` - Returns most recent non-prerelease
3. **Get by Tag**: `GET /repos/{owner}/{repo}/releases/tags/{tag}` - Get specific version

### Response Structure

```json
{
  "tag_name": "v1.9.0",
  "name": "v1.9.0",
  "published_at": "2025-11-29T00:00:00Z",
  "prerelease": false,
  "draft": false,
  "body": "## Changes...",
  "assets": [
    {
      "name": "sing-box-1.9.0-darwin-arm64.tar.gz",
      "browser_download_url": "https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-darwin-arm64.tar.gz",
      "size": 12345678,
      "content_type": "application/gzip",
      "download_count": 1234
    }
  ]
}
```

### Platform-Specific Asset Selection

For macOS (Darwin) on Apple Silicon (ARM64):
- **File pattern**: `sing-box-{version}-darwin-arm64.tar.gz` or `.zip`
- **Intel Macs**: `sing-box-{version}-darwin-amd64.tar.gz`
- **Detection**: Use `#if arch(arm64)` vs `#if arch(x86_64)` at compile time

### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **HTTP Client** | URLSession | Native, async/await support, no dependencies |
| **JSON Parsing** | Codable | Type-safe, performant, built-in |
| **Downloads** | URLSession.downloadTask | Background downloads, progress tracking, resume capability |
| **Metadata Storage** | SwiftData | Already in use, perfect for version records |
| **Binary Storage** | FileManager | Core binaries (10-30MB) stored in Application Support |
| **Version Comparison** | Swift PackageDescription.Version | Native semver support |

### Architecture Integration

**New Service: GitHubReleaseService**

```swift
protocol GitHubReleaseServiceProtocol {
    func fetchReleases(page: Int) async throws -> [Release]
    func fetchLatestRelease() async throws -> Release
    func fetchReleaseByTag(_ tag: String) async throws -> Release
}

final class GitHubReleaseService: GitHubReleaseServiceProtocol {
    private let baseURL = "https://api.github.com/repos/SagerNet/sing-box"
    private let session: URLSession
    
    func fetchReleases(page: Int = 1) async throws -> [Release] {
        let url = URL(string: "\(baseURL)/releases?page=\(page)&per_page=30")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([GitHubRelease].self, from: data)
            .map { $0.toDomainModel() }
    }
}
```

**Enhanced Service: CoreVersionService**

```swift
protocol CoreVersionServiceProtocol {
    // Existing
    func getInstalledVersions() -> [CoreVersion]
    func getActiveVersion() -> CoreVersion?
    
    // New - GitHub Integration
    func getAvailableVersions() async throws -> [CoreVersion]
    func downloadVersion(_ release: Release, asset: ReleaseAsset) async throws
    func getDownloadProgress(for version: String) -> AsyncStream<Double>
    func switchToVersion(_ version: String) throws
    func deleteVersion(_ version: String) throws
}
```

**New SwiftData Model: CoreVersion**

```swift
@Model
final class CoreVersion {
    @Attribute(.unique) var version: String
    var downloadDate: Date
    var isActive: Bool
    var fileSize: Int64
    var filePath: String
    var checksum: String?
    
    // GitHub metadata
    var githubTagName: String
    var githubPublishedAt: Date
    var githubPrerelease: Bool
}
```

### Storage Layout

```
~/Library/Application Support/Silent-Net.SilentX/
└── cores/
    ├── v1.9.0/
    │   ├── sing-box (binary)
    │   └── metadata.json
    └── v1.8.14/
        ├── sing-box
        └── metadata.json
```

### Error Handling

| Scenario | Detection | User Experience | Recovery |
|----------|-----------|-----------------|----------|
| Network unavailable | `URLError.notConnectedToInternet` | "No internet. Showing cached versions." | Show cached data, disable refresh |
| Rate limit hit | HTTP 403 + rate limit headers | "GitHub rate limit reached. Try again in X minutes." | Show countdown timer |
| Asset not found | No matching darwin-arm64 asset | "Version {X} not available for your platform." | Hide download button |
| Download interrupted | URLSession delegate error | "Download paused. Tap to resume." | Resume from checkpoint |
| Checksum mismatch | SHA256 comparison fail | "Downloaded file corrupted. Retrying..." | Auto-retry once |
| Extraction failed | Archive extraction error | "Cannot extract binary. File may be corrupted." | Delete partial, suggest re-download |

### Performance Optimizations

1. **Lazy Loading**: Only fetch first page (30 releases) initially, load more on scroll
2. **Caching**: Cache release list locally (SwiftData), refresh on user action or every 24h
3. **Background Refresh**: Check for new releases in background (if enabled)
4. **Download Queue**: Limit to 1 concurrent download to avoid bandwidth saturation
5. **Debouncing**: Prevent rapid repeated refresh button clicks (500ms)

### Security Considerations

1. **HTTPS Only**: Enforce TLS for all API calls and downloads
2. **Checksum Verification**: Always verify SHA256 digest before using binary
3. **Sandboxing**: Downloaded binaries stay in app's sandbox until user activates
4. **No Arbitrary Execution**: Only run binaries from known-safe GitHub releases
5. **Rate Limiting**: 60 req/hour without auth, 5000/hour with optional GitHub token

### Implementation Phases

1. **Phase 1**: Design data models and API contracts ✓ (this document)
2. **Phase 2**: Implement GitHubReleaseService with URLSession
3. **Phase 3**: Enhance CoreVersionService with download/extract logic
4. **Phase 4**: Update CoreVersionsView UI with real data binding
5. **Phase 5**: Add download progress UI and error handling
6. **Phase 6**: Implement version switching and active version management

### Alternatives Rejected

- **Web Scraping**: Fragile (breaks when GitHub changes HTML), violates ToS
- **Bundled Version List**: Requires app updates to show new versions
- **Custom Backend Proxy**: Unnecessary infrastructure, adds latency and costs

---

## References

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Apple Network Extension Documentation](https://developer.apple.com/documentation/networkextension)
- [Apple URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
- [GitHub REST API - Releases](https://docs.github.com/en/rest/releases/releases)
- [Sing-Box Documentation](https://sing-box.sagernet.org/)
- [Sing-Box Releases](https://github.com/SagerNet/sing-box/releases)
- [SFM Source Code](../../../RefRepo/sing-box-for-apple/)
- [Swift Semantic Versioning](https://github.com/apple/swift-package-manager/blob/main/Documentation/Versioning.md)

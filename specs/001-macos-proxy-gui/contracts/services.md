# Service Contracts: SilentX

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md)  
**Date**: December 6, 2025

This document defines the internal service contracts for SilentX. Since this is a native macOS application, contracts are defined as Swift protocols rather than REST/GraphQL APIs.

---

## ProfileService

Manages profile CRUD operations and import/export.

```swift
protocol ProfileServiceProtocol {
    // MARK: - CRUD Operations
    
    /// Creates a new empty profile
    /// - Parameter name: Display name for the profile
    /// - Returns: Newly created profile
    func createProfile(name: String) async throws -> Profile
    
    /// Retrieves all profiles sorted by order
    func getAllProfiles() async throws -> [Profile]
    
    /// Retrieves a specific profile by ID
    func getProfile(id: UUID) async throws -> Profile?
    
    /// Updates profile metadata (not nodes/rules)
    func updateProfile(_ profile: Profile) async throws
    
    /// Deletes a profile and all associated nodes/rules
    func deleteProfile(id: UUID) async throws
    
    /// Reorders profiles
    func reorderProfiles(_ profiles: [Profile]) async throws
    
    // MARK: - Import/Export
    
    /// Imports profile from URL (subscription or direct config)
    /// - Parameters:
    ///   - url: Remote URL containing configuration
    ///   - name: Optional name (defaults to URL-derived name)
    /// - Returns: Imported profile
    func importFromURL(_ url: URL, name: String?) async throws -> Profile
    
    /// Imports profile from local JSON file
    func importFromFile(_ fileURL: URL) async throws -> Profile
    
    /// Exports profile to JSON string
    func exportToJSON(_ profile: Profile) throws -> String
    
    /// Refreshes a remote profile
    func refreshProfile(_ profile: Profile) async throws
    
    // MARK: - Selection
    
    /// Sets the currently active profile for connection
    func setActiveProfile(_ profile: Profile) async throws
    
    /// Gets the currently active profile
    func getActiveProfile() async throws -> Profile?
}
```

### Error Types

```swift
enum ProfileError: LocalizedError {
    case notFound(UUID)
    case invalidURL(String)
    case networkError(Error)
    case parseError(String)
    case validationError(String)
    case duplicateName(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "Profile not found: \(id)"
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .parseError(let detail): return "Failed to parse configuration: \(detail)"
        case .validationError(let detail): return "Validation failed: \(detail)"
        case .duplicateName(let name): return "Profile name already exists: \(name)"
        }
    }
}
```

---

## NodeService

Manages proxy node CRUD and latency testing.

```swift
protocol NodeServiceProtocol {
    // MARK: - CRUD Operations
    
    /// Adds a new node to a profile
    func addNode(to profile: Profile, node: ProxyNode) async throws
    
    /// Gets all nodes for a profile
    func getNodes(for profile: Profile) async throws -> [ProxyNode]
    
    /// Updates an existing node
    func updateNode(_ node: ProxyNode) async throws
    
    /// Deletes a node
    func deleteNode(id: UUID) async throws
    
    /// Reorders nodes within a profile
    func reorderNodes(_ nodes: [ProxyNode], in profile: Profile) async throws
    
    // MARK: - Batch Operations
    
    /// Enables/disables multiple nodes
    func setNodesEnabled(_ nodes: [ProxyNode], enabled: Bool) async throws
    
    /// Deletes multiple nodes
    func deleteNodes(ids: [UUID]) async throws
    
    // MARK: - Latency Testing
    
    /// Tests latency for a single node
    /// - Returns: Latency in milliseconds, or nil if unreachable
    func testLatency(for node: ProxyNode) async throws -> Int?
    
    /// Tests latency for all nodes in a profile
    func testAllLatencies(for profile: Profile) async throws -> [UUID: Int?]
}
```

### Error Types

```swift
enum NodeError: LocalizedError {
    case notFound(UUID)
    case invalidAddress(String)
    case invalidPort(Int)
    case missingCredentials
    case unsupportedProtocol(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "Node not found: \(id)"
        case .invalidAddress(let addr): return "Invalid server address: \(addr)"
        case .invalidPort(let port): return "Invalid port: \(port)"
        case .missingCredentials: return "Protocol requires credentials"
        case .unsupportedProtocol(let proto): return "Unsupported protocol: \(proto)"
        }
    }
}
```

---

## RuleService

Manages routing rules.

```swift
protocol RuleServiceProtocol {
    // MARK: - CRUD Operations
    
    /// Adds a new rule to a profile
    func addRule(to profile: Profile, rule: RoutingRule) async throws
    
    /// Gets all rules for a profile (ordered by priority)
    func getRules(for profile: Profile) async throws -> [RoutingRule]
    
    /// Updates an existing rule
    func updateRule(_ rule: RoutingRule) async throws
    
    /// Deletes a rule
    func deleteRule(id: UUID) async throws
    
    /// Reorders rules (changes priority)
    func reorderRules(_ rules: [RoutingRule], in profile: Profile) async throws
    
    // MARK: - Batch Operations
    
    /// Enables/disables multiple rules
    func setRulesEnabled(_ rules: [RoutingRule], enabled: Bool) async throws
    
    /// Deletes multiple rules
    func deleteRules(ids: [UUID]) async throws
    
    // MARK: - Templates
    
    /// Gets predefined rule templates
    func getRuleTemplates() -> [RuleTemplate]
    
    /// Creates a rule from a template
    func createFromTemplate(_ template: RuleTemplate, for profile: Profile) async throws -> RoutingRule
}

struct RuleTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let matchType: RuleMatchType
    let matchValue: String
    let action: RuleAction
}
```

### Error Types

```swift
enum RuleError: LocalizedError {
    case notFound(UUID)
    case invalidMatchValue(RuleMatchType, String)
    case duplicateRule(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "Rule not found: \(id)"
        case .invalidMatchValue(let type, let value): 
            return "Invalid \(type.rawValue) pattern: \(value)"
        case .duplicateRule(let name): return "Rule already exists: \(name)"
        }
    }
}
```

---

## ConfigurationService

Handles JSON configuration generation and validation.

```swift
protocol ConfigurationServiceProtocol {
    /// Generates Sing-Box JSON configuration from a profile
    /// - Parameter profile: Source profile with nodes and rules
    /// - Returns: Valid Sing-Box JSON configuration string
    func generateConfig(from profile: Profile) throws -> String
    
    /// Validates JSON against Sing-Box schema
    /// - Parameter json: Raw JSON string
    /// - Returns: Validation result with any errors
    func validate(json: String) -> ConfigValidationResult
    
    /// Parses raw JSON and extracts nodes
    func parseNodes(from json: String) throws -> [ProxyNode]
    
    /// Parses raw JSON and extracts rules
    func parseRules(from json: String) throws -> [RoutingRule]
    
    /// Merges user-edited JSON with GUI-managed components
    func mergeConfiguration(base: String, nodes: [ProxyNode], rules: [RoutingRule]) throws -> String
}

struct ConfigValidationResult {
    let isValid: Bool
    let errors: [ConfigValidationError]
}

struct ConfigValidationError: Identifiable {
    let id = UUID()
    let line: Int?
    let column: Int?
    let message: String
    let severity: Severity
    
    enum Severity {
        case error
        case warning
        case info
    }
}
```

---

## CoreVersionService

Manages Sing-Box core binaries.

```swift
protocol CoreVersionServiceProtocol {
    /// Gets all cached core versions
    func getCachedVersions() async throws -> [CoreVersion]
    
    /// Gets the currently active core version
    func getActiveVersion() async throws -> CoreVersion?
    
    /// Downloads a specific core version
    /// - Parameters:
    ///   - version: Version string (e.g., "1.10.0")
    ///   - progress: Download progress callback
    func downloadVersion(_ version: String, progress: @escaping (Double) -> Void) async throws -> CoreVersion
    
    /// Downloads from a custom URL
    func downloadFromURL(_ url: URL, progress: @escaping (Double) -> Void) async throws -> CoreVersion
    
    /// Sets a cached version as active
    func setActiveVersion(_ version: CoreVersion) async throws
    
    /// Deletes a cached version
    func deleteVersion(_ version: CoreVersion) async throws
    
    /// Checks for new stable release
    func checkForUpdates() async throws -> CoreVersion?
    
    /// Gets available versions from GitHub releases
    func getAvailableVersions() async throws -> [AvailableVersion]
}

struct AvailableVersion {
    let version: String
    let releaseDate: Date
    let downloadURL: URL
    let releaseNotes: String?
    let isPrerelease: Bool
}
```

### Error Types

```swift
enum CoreVersionError: LocalizedError {
    case notFound(String)
    case downloadFailed(Error)
    case verificationFailed(String)
    case extractionFailed(Error)
    case insufficientSpace(Int64)
    case invalidBinary
    
    var errorDescription: String? {
        switch self {
        case .notFound(let v): return "Version not found: \(v)"
        case .downloadFailed(let e): return "Download failed: \(e.localizedDescription)"
        case .verificationFailed(let h): return "Hash verification failed: \(h)"
        case .extractionFailed(let e): return "Extraction failed: \(e.localizedDescription)"
        case .insufficientSpace(let need): return "Insufficient disk space. Need \(need) bytes"
        case .invalidBinary: return "Downloaded file is not a valid Sing-Box binary"
        }
    }
}
```

---

## ConnectionService

Manages proxy connection state (stub for MVP, real for post-MVP).

```swift
protocol ConnectionServiceProtocol {
    /// Current connection status
    var status: ConnectionStatus { get }
    
    /// Status publisher for observing changes
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { get }
    
    /// Starts proxy connection with active profile
    func connect() async throws
    
    /// Stops proxy connection
    func disconnect() async throws
    
    /// Restarts connection (for config changes)
    func restart() async throws
    
    /// Gets current connection statistics
    func getStatistics() async throws -> ConnectionStatistics
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting
    case error(String)
}

struct ConnectionStatistics {
    let uploadBytes: Int64
    let downloadBytes: Int64
    let uploadSpeed: Int64 // bytes per second
    let downloadSpeed: Int64
    let connectedDuration: TimeInterval?
}
```

---

## LogService

Manages log streaming and export.

```swift
protocol LogServiceProtocol {
    /// Stream of log entries
    var logStream: AsyncStream<LogEntry> { get }
    
    /// Gets recent log entries
    func getRecentLogs(limit: Int) async throws -> [LogEntry]
    
    /// Clears all logs
    func clearLogs() async throws
    
    /// Exports logs to file
    func exportLogs(to url: URL, filter: LogFilter?) async throws
    
    /// Sets log level filter
    func setLogLevel(_ level: LogLevel) async
}

struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
}

enum LogLevel: String, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

struct LogFilter {
    var minLevel: LogLevel?
    var categories: [String]?
    var searchText: String?
    var startDate: Date?
    var endDate: Date?
}
```

---

## Service Dependencies

```
┌─────────────────┐     ┌──────────────────┐
│  ProfileService │────▶│ ConfigurationSvc │
└────────┬────────┘     └──────────────────┘
         │
         │ uses
         ▼
┌─────────────────┐     ┌─────────────────┐
│   NodeService   │     │   RuleService   │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │ generates config for
                     ▼
              ┌──────────────────┐
              │ ConnectionService│
              └────────┬─────────┘
                       │
                       │ writes to
                       ▼
              ┌─────────────────┐
              │   LogService    │
              └─────────────────┘

┌───────────────────┐
│ CoreVersionService│  (independent)
└───────────────────┘
```

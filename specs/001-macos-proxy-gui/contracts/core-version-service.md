# API Contract: CoreVersionService (Enhanced)

**Feature**: Core Version Management with GitHub Integration  
**Date**: 2025-12-06

## Service Interface

```swift
protocol CoreVersionServiceProtocol {
    // MARK: - Local Version Management (Existing)
    
    /// Get all installed core versions
    /// - Returns: Array of CoreVersion from SwiftData
    func getInstalledVersions() -> [CoreVersion]
    
    /// Get the currently active core version
    /// - Returns: Active CoreVersion, or nil if none active
    func getActiveVersion() -> CoreVersion?
    
    // MARK: - GitHub Integration (New)
    
    /// Fetch available versions from GitHub
    /// - Returns: Array of Release objects from GitHub API
    /// - Throws: CoreVersionError on network failure
    func getAvailableVersions() async throws -> [Release]
    
    /// Download a core binary from GitHub
    /// - Parameters:
    ///   - release: GitHub Release object
    ///   - asset: Specific asset to download
    /// - Throws: CoreVersionError on download/extraction failure
    func downloadVersion(_ release: Release, asset: ReleaseAsset) async throws
    
    /// Monitor download progress for a version
    /// - Parameter version: Version string (e.g., "1.9.0")
    /// - Returns: AsyncStream emitting progress 0.0-1.0
    func getDownloadProgress(for version: String) -> AsyncStream<Double>
    
    /// Switch to a different installed version
    /// - Parameter version: Version to activate
    /// - Throws: CoreVersionError if version not installed
    func switchToVersion(_ version: String) throws
    
    /// Delete an installed version
    /// - Parameter version: Version to delete
    /// - Throws: CoreVersionError if version is active or not found
    func deleteVersion(_ version: String) throws
    
    /// Verify downloaded binary integrity
    /// - Parameters:
    ///   - filePath: Path to downloaded file
    ///   - expectedChecksum: SHA256 digest from GitHub
    /// - Returns: true if checksum matches
    func verifyChecksum(filePath: String, expectedChecksum: String) -> Bool
}
```

---

## Method Specifications

### 1. getInstalledVersions()

**Purpose**: Retrieve all locally installed core versions

**Implementation**:
```swift
func getInstalledVersions() -> [CoreVersion] {
    let descriptor = FetchDescriptor<CoreVersion>(
        sortBy: [SortDescriptor(\.downloadDate, order: .reverse)]
    )
    return (try? modelContext.fetch(descriptor)) ?? []
}
```

**Returns**: Array ordered by `downloadDate` (newest first)

**Error Handling**: Returns empty array on SwiftData errors (non-throwing)

---

### 2. getActiveVersion()

**Purpose**: Get the currently active core version

**Implementation**:
```swift
func getActiveVersion() -> CoreVersion? {
    let predicate = #Predicate<CoreVersion> { $0.isActive }
    let descriptor = FetchDescriptor(predicate: predicate)
    return try? modelContext.fetch(descriptor).first
}
```

**Invariant**: Maximum 1 version with `isActive = true`

---

### 3. getAvailableVersions()

**Purpose**: Fetch releases from GitHub API

**Implementation**:
```swift
func getAvailableVersions() async throws -> [Release] {
    // Delegate to GitHubReleaseService
    let releases = try await githubService.fetchReleases(page: 1)
    
    // Filter to stable releases only (optional)
    return releases.filter { !$0.draft && !$0.prerelease }
}
```

**Caching**: Results cached in-memory for 30 minutes

**Error Handling**:
```swift
// Network unavailable
throw CoreVersionError.networkUnavailable

// Rate limit
throw CoreVersionError.rateLimitExceeded(resetTime: resetDate)
```

---

### 4. downloadVersion(_ release: Release, asset: ReleaseAsset)

**Purpose**: Download and install a core binary from GitHub

**Implementation Flow**:
1. **Pre-check**: Verify version not already installed
2. **Disk space check**: Ensure sufficient space (100 MB minimum)
3. **Download**: Use `URLSession.downloadTask` with progress tracking
4. **Verify**: Check SHA256 checksum matches `asset.digest`
5. **Extract**: Decompress tar.gz/zip archive
6. **Install**: Move binary to `~/Library/Application Support/Silent-Net.SilentX/cores/{version}/`
7. **Persist**: Save CoreVersion record to SwiftData

**Error Handling**:
```swift
// Already installed
throw CoreVersionError.versionAlreadyInstalled(release.version)

// Insufficient disk space
let required: Int64 = 100_000_000  // 100 MB
let available = FileManager.default.availableDiskSpace
guard available >= required else {
    throw CoreVersionError.insufficientDiskSpace(required: required, available: available)
}

// Download failed
throw CoreVersionError.downloadFailed(url: asset.downloadURL, reason: error.localizedDescription)

// Checksum mismatch
throw CoreVersionError.checksumMismatch(expected: asset.digest!, actual: actualDigest)

// Extraction failed
throw CoreVersionError.extractionFailed(path: archivePath)
```

**Progress Tracking**: Emits progress via `getDownloadProgress(for:)`

---

### 5. getDownloadProgress(for version: String)

**Purpose**: Monitor download progress in real-time

**Implementation**:
```swift
func getDownloadProgress(for version: String) -> AsyncStream<Double> {
    AsyncStream { continuation in
        let task = downloadTasks[version]
        let observation = task?.progress.observe(\.fractionCompleted) { progress, _ in
            continuation.yield(progress.fractionCompleted)
        }
        
        continuation.onTermination = { _ in
            observation?.invalidate()
        }
    }
}
```

**Usage**:
```swift
for await progress in service.getDownloadProgress(for: "1.9.0") {
    print("Download: \(Int(progress * 100))%")
}
```

---

### 6. switchToVersion(_ version: String)

**Purpose**: Set a different installed version as active

**Implementation**:
```swift
func switchToVersion(_ version: String) throws {
    guard let newVersion = findVersion(version) else {
        throw CoreVersionError.assetNotFound(platform: version)
    }
    
    // Deactivate current active version
    if let currentActive = getActiveVersion() {
        currentActive.isActive = false
    }
    
    // Activate new version
    newVersion.isActive = true
    
    try modelContext.save()
}
```

**Side Effects**:
- Updates `isActive` flag in SwiftData
- May require app restart to take effect (if core is currently running)

**Error Handling**:
```swift
// Version not found
throw CoreVersionError.assetNotFound(platform: version)
```

---

### 7. deleteVersion(_ version: String)

**Purpose**: Remove an installed version from disk and database

**Implementation**:
```swift
func deleteVersion(_ version: String) throws {
    guard let coreVersion = findVersion(version) else {
        throw CoreVersionError.assetNotFound(platform: version)
    }
    
    guard !coreVersion.isActive else {
        throw CoreVersionError.binaryNotExecutable(path: "Cannot delete active version")
    }
    
    // Delete binary from disk
    try FileManager.default.removeItem(atPath: coreVersion.filePath)
    
    // Delete from database
    modelContext.delete(coreVersion)
    try modelContext.save()
}
```

**Error Handling**:
```swift
// Cannot delete active version
throw CoreVersionError.binaryNotExecutable(path: "Cannot delete active version")

// File system error
throw CoreVersionError.extractionFailed(path: coreVersion.filePath)
```

---

### 8. verifyChecksum(filePath: String, expectedChecksum: String)

**Purpose**: Verify file integrity using SHA256

**Implementation**:
```swift
import CryptoKit

func verifyChecksum(filePath: String, expectedChecksum: String) -> Bool {
    guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return false
    }
    
    let digest = SHA256.hash(data: fileData)
    let actualChecksum = digest.compactMap { String(format: "%02x", $0) }.joined()
    
    return actualChecksum.lowercased() == expectedChecksum.lowercased()
}
```

**Performance**: ~500ms for 20 MB file

---

## State Management

### Thread Safety

**Main Actor Isolation**: All SwiftData operations run on `@MainActor`

```swift
@MainActor
final class CoreVersionService: CoreVersionServiceProtocol {
    private let modelContext: ModelContext
    private let githubService: GitHubReleaseServiceProtocol
    
    // Downloads tracked in actor-isolated storage
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
}
```

---

## Storage Paths

### Directory Structure

```swift
// Base directory
let appSupport = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
).first!

let coresDir = appSupport
    .appendingPathComponent("Silent-Net.SilentX")
    .appendingPathComponent("cores")

// Version-specific directory
let versionDir = coresDir.appendingPathComponent("v1.9.0")
let binaryPath = versionDir.appendingPathComponent("sing-box")
```

**Paths**:
- **Cores root**: `~/Library/Application Support/Silent-Net.SilentX/cores/`
- **Version dir**: `.../cores/v1.9.0/`
- **Binary**: `.../cores/v1.9.0/sing-box`

---

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| `getInstalledVersions()` | < 50 ms | SwiftData fetch |
| `getActiveVersion()` | < 10 ms | Predicate query |
| `getAvailableVersions()` | < 2 seconds | Network call (cached) |
| `downloadVersion()` | Progress feedback | 10-30 MB at user's bandwidth |
| `switchToVersion()` | < 500 ms | Database + file system |
| `deleteVersion()` | < 1 second | File deletion |
| `verifyChecksum()` | < 1 second | SHA256 of 20 MB |

---

## Testing

### Mock Implementation

```swift
final class MockCoreVersionService: CoreVersionServiceProtocol {
    var installedVersions: [CoreVersion] = []
    var activeVersion: CoreVersion?
    var availableReleases: [Release] = [Release.mock]
    
    func getInstalledVersions() -> [CoreVersion] {
        installedVersions
    }
    
    func getActiveVersion() -> CoreVersion? {
        activeVersion
    }
    
    func getAvailableVersions() async throws -> [Release] {
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s delay
        return availableReleases
    }
    
    func downloadVersion(_ release: Release, asset: ReleaseAsset) async throws {
        // Simulate download
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1s
        
        let newVersion = CoreVersion(
            version: release.version,
            filePath: "/mock/path/\(release.version)/sing-box",
            fileSize: asset.size,
            githubTagName: release.tagName,
            githubPublishedAt: release.publishedAt ?? Date(),
            githubPrerelease: release.prerelease
        )
        installedVersions.append(newVersion)
    }
    
    // ... other methods
}
```

---

## Dependencies

**Injected Services**:
1. **ModelContext**: SwiftData persistence
2. **GitHubReleaseService**: GitHub API client
3. **FileManager**: Disk operations (default instance)

**Initialization**:
```swift
init(
    modelContext: ModelContext,
    githubService: GitHubReleaseServiceProtocol = GitHubReleaseService()
) {
    self.modelContext = modelContext
    self.githubService = githubService
}
```

---

## References

- [URLSession Downloads](https://developer.apple.com/documentation/foundation/urlsession/downloading_files_in_the_background)
- [CryptoKit SHA256](https://developer.apple.com/documentation/cryptokit/sha256)
- [AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)

# Data Model: Core Version Management with GitHub Integration

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)  
**Date**: 2025-12-06

## Overview

This document defines the data models for integrating real-time core version management with GitHub Releases API. The system tracks both **remote versions** (available on GitHub) and **local versions** (downloaded binaries).

---

## Entity: CoreVersion (SwiftData - Enhanced)

**Purpose**: Tracks downloaded sing-box core binaries with GitHub metadata.

```swift
@Model
final class CoreVersion {
    @Attribute(.unique) var version: String  // "1.9.0"
    var filePath: String
    var fileSize: Int64
    var downloadDate: Date
    var isActive: Bool
    var checksum: String?
    
    // NEW: GitHub metadata
    var githubTagName: String                // "v1.9.0"
    var githubPublishedAt: Date
    var githubPrerelease: Bool
    var githubBody: String?                  // Release notes
}
```

---

## Entity: Release (Domain Model)

**Purpose**: Represents GitHub release (in-memory, not persisted).

```swift
struct Release: Identifiable {
    let id: Int
    let tagName: String                      // "v1.9.0"
    let name: String
    let body: String                         // Markdown release notes
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [ReleaseAsset]
    
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
    
    var preferredAsset: ReleaseAsset? {
        #if arch(arm64)
        assets.first { $0.name.contains("darwin-arm64") }
        #else
        assets.first { $0.name.contains("darwin-amd64") }
        #endif
    }
}
```

---

## Entity: ReleaseAsset (Domain Model)

**Purpose**: Downloadable file from GitHub release.

```swift
struct ReleaseAsset: Identifiable {
    let id: Int
    let name: String                         // "sing-box-1.9.0-darwin-arm64.tar.gz"
    let size: Int64
    let downloadURL: URL
    let digest: String?                      // SHA256
    
    var isMacOSCompatible: Bool {
        name.lowercased().contains("darwin")
    }
}
```

---

## State Transitions

```
GitHub Release → Download → Verify → Extract → Install → Activate
                   ↓          ↓        ↓         ↓         ↓
                Progress   SHA256   Decompress  File    isActive=true
```

---

## Common Queries

```swift
// Get active version
@Query(filter: #Predicate<CoreVersion> { $0.isActive })
var activeVersion: [CoreVersion]

// Get all installed, sorted by download date
@Query(sort: \CoreVersion.downloadDate, order: .reverse)
var installedVersions: [CoreVersion]
```

---

## Error Handling

```swift
enum CoreVersionError: LocalizedError {
    case networkUnavailable
    case rateLimitExceeded(resetTime: Date)
    case assetNotFound(platform: String)
    case downloadFailed(url: URL, reason: String)
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(path: String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case versionAlreadyInstalled(String)
}
```

---

## Storage Layout

```
~/Library/Application Support/Silent-Net.SilentX/cores/
├── v1.9.0/
│   └── sing-box (binary)
└── v1.8.14/
    └── sing-box
```

**Disk Usage**: ~25-75 MB per version (avg 50 MB)

---

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Fetch releases | < 2s | First 30 releases |
| Download core | Progress feedback | 10-30 MB |
| Verify checksum | < 1s | SHA256 |
| Switch version | < 500ms | File operation |

---

## References

- [SwiftData Schema](https://developer.apple.com/documentation/swiftdata/schema)
- [GitHub API Releases](https://docs.github.com/en/rest/releases/releases#list-releases)

# API Contract: GitHubReleaseService

**Feature**: Core Version Management  
**Date**: 2025-12-06

## Service Interface

```swift
protocol GitHubReleaseServiceProtocol {
    /// Fetch paginated list of releases
    /// - Parameter page: Page number (1-indexed, default: 1)
    /// - Returns: Array of Release objects
    /// - Throws: CoreVersionError on network/parsing failure
    func fetchReleases(page: Int) async throws -> [Release]
    
    /// Fetch the latest stable release
    /// - Returns: Most recent non-prerelease Release
    /// - Throws: CoreVersionError.networkUnavailable, .rateLimitExceeded
    func fetchLatestRelease() async throws -> Release
    
    /// Fetch a specific release by tag name
    /// - Parameter tag: Git tag (e.g., "v1.9.0")
    /// - Returns: Release matching the tag
    /// - Throws: CoreVersionError if not found
    func fetchReleaseByTag(_ tag: String) async throws -> Release
}
```

---

## Endpoint Specifications

### 1. List Releases

**HTTP Method**: `GET`  
**Endpoint**: `/repos/SagerNet/sing-box/releases`  
**Query Parameters**:
- `page`: integer (default: 1)
- `per_page`: integer (default: 30, max: 100)

**Request Headers**:
```http
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
```

**Success Response** (200 OK):
```json
[
  {
    "id": 123456,
    "tag_name": "v1.9.0",
    "name": "v1.9.0",
    "body": "## Changes\n- Feature A",
    "draft": false,
    "prerelease": false,
    "created_at": "2025-11-29T00:00:00Z",
    "published_at": "2025-11-29T00:00:00Z",
    "assets": [
      {
        "id": 789,
        "name": "sing-box-1.9.0-darwin-arm64.tar.gz",
        "size": 15728640,
        "browser_download_url": "https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-darwin-arm64.tar.gz",
        "content_type": "application/gzip",
        "download_count": 1234,
        "digest": "sha256:abc123..."
      }
    ]
  }
]
```

**Error Responses**:
- **403 Forbidden**: Rate limit exceeded
  ```json
  {
    "message": "API rate limit exceeded",
    "documentation_url": "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
  }
  ```
  Headers include: `X-RateLimit-Reset: 1733500000`

- **404 Not Found**: Repository doesn't exist

---

### 2. Get Latest Release

**HTTP Method**: `GET`  
**Endpoint**: `/repos/SagerNet/sing-box/releases/latest`

**Success Response**: Same structure as single release from List Releases

---

### 3. Get Release by Tag

**HTTP Method**: `GET`  
**Endpoint**: `/repos/SagerNet/sing-box/releases/tags/{tag}`  
**Path Parameter**: `tag` (e.g., "v1.9.0")

**Success Response**: Same structure as single release

**Error Responses**:
- **404 Not Found**: Tag doesn't exist

---

## Rate Limiting

**Without Authentication**:
- **Limit**: 60 requests/hour
- **Detection**: Check `X-RateLimit-Remaining` header
- **Reset**: `X-RateLimit-Reset` header (Unix timestamp)

**With GitHub Token** (Optional):
- **Limit**: 5000 requests/hour
- **Implementation**: Add `Authorization: Bearer <token>` header

---

## Error Handling Contract

```swift
// Network errors
throw CoreVersionError.networkUnavailable  // URLError.notConnectedToInternet

// Rate limiting
let resetDate = Date(timeIntervalSince1970: resetTimestamp)
throw CoreVersionError.rateLimitExceeded(resetTime: resetDate)

// Parsing errors
throw CoreVersionError.invalidDateFormat(dateString)

// Asset errors
throw CoreVersionError.assetNotFound(platform: "darwin-arm64")
```

---

## Data Transformation

### GitHub API → Domain Model

```swift
// GitHubRelease (API) → Release (Domain)
func transform(_ apiRelease: GitHubRelease) throws -> Release {
    let dateFormatter = ISO8601DateFormatter()
    guard let createdDate = dateFormatter.date(from: apiRelease.createdAt) else {
        throw CoreVersionError.invalidDateFormat(apiRelease.createdAt)
    }
    
    return Release(
        id: apiRelease.id,
        tagName: apiRelease.tagName,
        name: apiRelease.name,
        body: apiRelease.body,
        prerelease: apiRelease.prerelease,
        publishedAt: apiRelease.publishedAt.flatMap { dateFormatter.date(from: $0) },
        assets: apiRelease.assets.map(transform)
    )
}
```

---

## Caching Strategy

**Implementation**: Not part of service contract (handled by CoreVersionService)

**Recommendation**:
- Cache responses in SwiftData with `lastFetched` timestamp
- Refresh if `lastFetched > 24 hours` OR user triggers manual refresh
- Use cached data when offline

---

## Testing

### Mock Responses

```swift
struct MockGitHubReleaseService: GitHubReleaseServiceProtocol {
    func fetchReleases(page: Int) async throws -> [Release] {
        [Release.mock, Release.mockPrerelease]
    }
    
    func fetchLatestRelease() async throws -> Release {
        Release.mock
    }
    
    func fetchReleaseByTag(_ tag: String) async throws -> Release {
        guard tag == "v1.9.0" else {
            throw CoreVersionError.assetNotFound(platform: tag)
        }
        return Release.mock
    }
}
```

---

## Security

1. **HTTPS Only**: All requests use `https://` scheme
2. **No Credentials**: Public API, no GitHub token stored by default
3. **User-Provided Token** (Optional): Stored in macOS Keychain if user adds one
4. **Rate Limit Respect**: Exponential backoff on rate limit errors

---

## Performance SLA

| Operation | Expected Duration | Timeout |
|-----------|------------------|---------|
| `fetchReleases()` | < 2 seconds | 10 seconds |
| `fetchLatestRelease()` | < 1.5 seconds | 10 seconds |
| `fetchReleaseByTag()` | < 1.5 seconds | 10 seconds |

**Network Configuration**:
```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 10.0
config.timeoutIntervalForResource = 30.0
let session = URLSession(configuration: config)
```

---

## References

- [GitHub REST API - Releases](https://docs.github.com/en/rest/releases/releases)
- [GitHub API Rate Limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)

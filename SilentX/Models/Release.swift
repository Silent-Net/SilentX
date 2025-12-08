//
//  Release.swift
//  SilentX
//
//  Domain model for GitHub release information
//

import Foundation

/// Represents a GitHub release
struct Release: Codable, Identifiable {
    /// Unique release ID from GitHub
    let id: Int
    
    /// Git tag name (e.g., "v1.8.0")
    let tagName: String
    
    /// Human-readable release name
    let name: String?
    
    /// Release notes / changelog in Markdown
    let body: String?
    
    /// Whether this is a prerelease version
    let prerelease: Bool
    
    /// Publication timestamp
    let publishedAt: Date
    
    /// Release assets (binaries, checksums, etc.)
    let assets: [ReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

extension Release {
    /// Find asset by filename
    func asset(named filename: String) -> ReleaseAsset? {
        assets.first { $0.name == filename }
    }
    
    /// Find asset matching a pattern (e.g., contains "darwin-amd64")
    func asset(matching pattern: String) -> ReleaseAsset? {
        assets.first { $0.name.contains(pattern) }
    }
}

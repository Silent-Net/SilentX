//
//  ReleaseAsset.swift
//  SilentX
//
//  Domain model for GitHub release asset (binary download)
//

import Foundation

/// Represents a downloadable asset from a GitHub release
struct ReleaseAsset: Codable, Identifiable {
    /// Unique asset ID from GitHub
    let id: Int
    
    /// Filename (e.g., "sing-box-1.8.0-darwin-amd64.tar.gz")
    let name: String
    
    /// File size in bytes
    let size: Int
    
    /// Direct download URL
    let downloadURL: URL
    
    /// SHA256 digest for verification (optional, may need separate fetch)
    var digest: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case downloadURL = "browser_download_url"
    }
}

extension ReleaseAsset {
    /// Check if this is a macOS binary
    var isMacOSBinary: Bool {
        name.contains("darwin") && (name.contains("amd64") || name.contains("arm64"))
    }
    
    /// Check if this is a checksum file
    var isChecksum: Bool {
        name.hasSuffix(".sha256sum") || name.hasSuffix(".sha256")
    }
    
    /// Formatted size (e.g., "12.5 MB")
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

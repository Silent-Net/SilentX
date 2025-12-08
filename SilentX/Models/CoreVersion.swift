//
//  CoreVersion.swift
//  SilentX
//
//  CoreVersion entity - represents a cached Sing-Box binary
//

import Foundation
import SwiftData

/// Represents a cached Sing-Box core binary
@Model
final class CoreVersion {
    /// Semantic version string (serves as primary key)
    @Attribute(.unique) var version: String
    
    /// Source URL for download
    var downloadURL: String
    
    /// Local file path if downloaded
    var localPath: String?
    
    /// When the version was downloaded
    var downloadDate: Date?
    
    /// Whether this is the currently active version
    var isActive: Bool
    
    /// SHA-256 hash for verification
    var fileHash: String?
    
    /// Release notes from GitHub
    var releaseNotes: String?
    
    /// Whether this is a pre-release version
    var isPrerelease: Bool
    
    // MARK: - Initialization
    
    init(
        version: String,
        downloadURL: String,
        isPrerelease: Bool = false
    ) {
        self.version = version
        self.downloadURL = downloadURL
        self.isActive = false
        self.isPrerelease = isPrerelease
    }
    
    // MARK: - Computed Properties
    
    /// Whether the version is downloaded and available locally
    var isDownloaded: Bool {
        guard let path = localPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Display string for version with pre-release indicator
    var displayVersion: String {
        isPrerelease ? "\(version) (Pre-release)" : version
    }
    
    /// Status display string
    var statusDisplay: String {
        if isActive {
            return "Active"
        } else if isDownloaded {
            return "Downloaded"
        } else {
            return "Available"
        }
    }
    
    /// URL object for download
    var downloadURLObject: URL? {
        URL(string: downloadURL)
    }
}

// MARK: - Validation

extension CoreVersion {
    /// Validates the core version data
    func validate() throws {
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CoreVersionValidationError.emptyVersion
        }
        
        guard URL(string: downloadURL) != nil else {
            throw CoreVersionValidationError.invalidDownloadURL
        }
        
        // If marked as active, must have local path
        if isActive && localPath == nil {
            throw CoreVersionValidationError.activeWithoutLocalPath
        }
    }
}

/// Core version validation errors
enum CoreVersionValidationError: LocalizedError {
    case emptyVersion
    case invalidDownloadURL
    case activeWithoutLocalPath
    
    var errorDescription: String? {
        switch self {
        case .emptyVersion:
            return "Version cannot be empty"
        case .invalidDownloadURL:
            return "Invalid download URL"
        case .activeWithoutLocalPath:
            return "Active version must have a local path"
        }
    }
}

// MARK: - Comparable

extension CoreVersion: Comparable {
    static func < (lhs: CoreVersion, rhs: CoreVersion) -> Bool {
        // Simple version comparison - could be enhanced with semantic versioning
        lhs.version.compare(rhs.version, options: .numeric) == .orderedAscending
    }
    
    static func == (lhs: CoreVersion, rhs: CoreVersion) -> Bool {
        lhs.version == rhs.version
    }
}

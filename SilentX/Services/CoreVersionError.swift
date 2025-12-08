//
//  CoreVersionError.swift
//  SilentX
//
//  Error types for core version operations
//

import Foundation

/// Errors that can occur during core version operations
enum CoreVersionError: LocalizedError {
    case downloadFailed(String)
    case invalidURL
    case extractionFailed
    case versionNotFound(String)
    case versionInUse
    case networkUnavailable
    case insufficientPermissions
    case corruptedArchive
    case unsupportedPlatform
    case verificationFailed
    case alreadyDownloaded
    
    // GitHub API errors
    case rateLimitExceeded(resetTime: Date)
    case networkError(statusCode: Int)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .invalidURL:
            return "Invalid URL provided"
        case .extractionFailed:
            return "Failed to extract downloaded archive"
        case .versionNotFound(let version):
            return "Version \(version) not found"
        case .versionInUse:
            return "Cannot delete version currently in use"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .insufficientPermissions:
            return "Insufficient permissions to manage core files"
        case .corruptedArchive:
            return "Downloaded archive is corrupted"
        case .unsupportedPlatform:
            return "No binary available for this platform"
        case .verificationFailed:
            return "Checksum verification failed"
        case .alreadyDownloaded:
            return "This version is already downloaded"
        case .rateLimitExceeded(let resetTime):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: resetTime, relativeTo: Date())
            return "GitHub rate limit exceeded. Try again \(relative)."
        case .networkError(let statusCode):
            return "Network error (HTTP \(statusCode))"
        case .decodingFailed(let reason):
            return "Failed to parse response: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .downloadFailed:
            return "Check your internet connection and try again"
        case .invalidURL:
            return "Please enter a valid download URL"
        case .extractionFailed:
            return "The download may be corrupted. Try downloading again"
        case .versionNotFound:
            return "Check the version number or try refreshing available versions"
        case .versionInUse:
            return "Switch to a different version before deleting"
        case .networkUnavailable:
            return "Connect to the internet and try again"
        case .insufficientPermissions:
            return "Check file permissions in the core storage directory"
        case .corruptedArchive:
            return "Try downloading the file again"
        case .unsupportedPlatform:
            return "Download the correct binary for your system architecture"
        case .verificationFailed:
            return "The file may have been tampered with. Download from official sources"
        case .alreadyDownloaded:
            return "Use the existing downloaded version"
        case .rateLimitExceeded:
            return "Wait for the rate limit to reset, or add a GitHub personal access token in Settings to increase your limit"
        case .networkError:
            return "Check your internet connection and try again"
        case .decodingFailed:
            return "GitHub API response format may have changed. Check for app updates"
        }
    }
}

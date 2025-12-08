//
//  ProfileError.swift
//  SilentX
//
//  Profile-related errors with localized descriptions
//

import Foundation

/// Errors that can occur during profile operations
enum ProfileError: LocalizedError {
    /// Profile name is empty or invalid
    case invalidName(String)
    
    /// Configuration JSON is invalid
    case invalidConfiguration(String)
    
    /// Failed to download remote profile
    case downloadFailed(String)
    
    /// Cannot access the file
    case fileAccessDenied
    
    /// Cannot read the file contents
    case fileReadError(String)
    
    /// Cannot export profile
    case exportFailed(String)
    
    /// Profile is not a remote profile (for refresh operations)
    case notRemoteProfile
    
    /// Profile not found
    case notFound
    
    /// Profile already exists with this name
    case duplicateName
    
    /// Server returned 5xx error (retryable)
    case serverError(Int)
    
    /// Rate limited by server (429)
    case rateLimited
    
    /// Generic profile operation failure
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName(let detail):
            return "Invalid profile name: \(detail)"
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .downloadFailed(let detail):
            return "Download failed: \(detail)"
        case .fileAccessDenied:
            return "Cannot access file. Please grant permission."
        case .fileReadError(let detail):
            return "Cannot read file: \(detail)"
        case .exportFailed(let detail):
            return "Export failed: \(detail)"
        case .notRemoteProfile:
            return "This operation is only available for remote profiles"
        case .notFound:
            return "Profile not found"
        case .duplicateName:
            return "A profile with this name already exists"
        case .serverError(let statusCode):
            return "Server error: HTTP \(statusCode)"
        case .rateLimited:
            return "Too many requests. Please wait before trying again."
        case .operationFailed(let detail):
            return "Operation failed: \(detail)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Enter a valid profile name."
        case .invalidConfiguration:
            return "Check the configuration JSON format and required fields."
        case .downloadFailed:
            return "Check your internet connection and the URL."
        case .fileAccessDenied:
            return "Grant file access permission in System Settings."
        case .fileReadError:
            return "Make sure the file exists and is readable."
        case .exportFailed:
            return "Try exporting to a different location."
        case .notRemoteProfile:
            return "Only remote profiles can be refreshed."
        case .notFound:
            return "The profile may have been deleted."
        case .duplicateName:
            return "Choose a different name for the profile."
        case .serverError:
            return "The server is experiencing issues. Try again later."
        case .rateLimited:
            return "Wait a few minutes before retrying."
        case .operationFailed:
            return "Try the operation again."
        }
    }
}

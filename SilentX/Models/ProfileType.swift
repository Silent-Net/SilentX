//
//  ProfileType.swift
//  SilentX
//
//  Profile source type enumeration
//

import Foundation

/// Represents the source type of a profile
enum ProfileType: Int, Codable, CaseIterable {
    /// User-created local profile
    case local = 0
    
    /// Imported from remote URL
    case remote = 1
    
    /// Synced via iCloud
    case icloud = 2
    
    /// Human-readable description
    var description: String {
        switch self {
        case .local: return "Local"
        case .remote: return "Remote"
        case .icloud: return "iCloud"
        }
    }
    
    /// SF Symbol name for the type
    var systemImage: String {
        switch self {
        case .local: return "doc"
        case .remote: return "cloud"
        case .icloud: return "icloud"
        }
    }
}

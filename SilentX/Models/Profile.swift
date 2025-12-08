//
//  Profile.swift
//  SilentX
//
//  Profile entity - represents a complete proxy configuration
//

import Foundation
import SwiftData

/// Represents a complete proxy configuration profile
@Model
final class Profile {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// User-facing display name
    var name: String
    
    /// Sort order in profile list
    var order: Int
    
    /// Source type (local, remote, iCloud)
    var type: ProfileType
    
    /// Raw Sing-Box JSON configuration
    var configurationJSON: String
    
    /// Source URL for remote profiles
    var remoteURL: String?
    
    /// Whether automatic updates are enabled
    var autoUpdate: Bool
    
    /// Update interval in hours
    var autoUpdateInterval: Int
    
    /// Timestamp of last successful update
    var lastUpdated: Date?
    
    /// Timestamp when profile was last modified (for sorting)
    var updatedAt: Date
    
    /// Timestamp of last sync attempt (distinct from lastUpdated)
    var lastSyncAt: Date?
    
    /// Subscription metadata - ETag from last fetch
    var subscriptionETag: String?
    
    /// Subscription metadata - Last-Modified header from last fetch
    var subscriptionLastModified: String?
    
    /// Last sync status message
    var lastSyncStatus: String?
    
    /// Profile creation timestamp
    var createdAt: Date
    
    /// Whether this profile is currently selected/active
    var isSelected: Bool

    /// Preferred proxy engine type for this profile (stored as optional for migration compatibility)
    private var _preferredEngine: EngineType?

    /// Preferred proxy engine type for this profile
    var preferredEngine: EngineType {
        get { _preferredEngine ?? .localProcess }
        set { _preferredEngine = newValue }
    }

    // MARK: - Relationships
    
    /// Proxy nodes belonging to this profile
    @Relationship(deleteRule: .cascade, inverse: \ProxyNode.profile)
    var nodes: [ProxyNode] = []
    
    /// Routing rules belonging to this profile
    @Relationship(deleteRule: .cascade, inverse: \RoutingRule.profile)
    var rules: [RoutingRule] = []
    
    // MARK: - Initialization
    
    init(
        name: String,
        type: ProfileType = .local,
        configurationJSON: String = "{}",
        remoteURL: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.order = 0
        self.type = type
        self.configurationJSON = configurationJSON
        self.remoteURL = remoteURL
        self.autoUpdate = type == .remote
        self.autoUpdateInterval = Constants.defaultAutoUpdateInterval
        self.lastSyncAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSelected = false
        self.preferredEngine = .localProcess
    }
    
    // MARK: - Computed Properties
    
    /// Number of enabled nodes
    var enabledNodesCount: Int {
        nodes.filter { $0.isEnabled }.count
    }
    
    /// Number of enabled rules
    var enabledRulesCount: Int {
        rules.filter { $0.isEnabled }.count
    }
    
    /// Whether the profile can be updated (remote profiles only)
    var canUpdate: Bool {
        type == .remote && remoteURL != nil
    }
}

// MARK: - Validation

extension Profile {
    /// Validates the profile data
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileValidationError.emptyName
        }
        
        guard name.count <= Constants.maxProfileNameLength else {
            throw ProfileValidationError.nameTooLong
        }
        
        if type == .remote {
            guard let urlString = remoteURL,
                  URL(string: urlString) != nil else {
                throw ProfileValidationError.invalidRemoteURL
            }
        }
        
        guard autoUpdateInterval >= Constants.minAutoUpdateInterval,
              autoUpdateInterval <= Constants.maxAutoUpdateInterval else {
            throw ProfileValidationError.invalidUpdateInterval
        }
    }
}

/// Profile validation errors
enum ProfileValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case invalidRemoteURL
    case invalidUpdateInterval
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Profile name cannot be empty"
        case .nameTooLong:
            return "Profile name is too long (max \(Constants.maxProfileNameLength) characters)"
        case .invalidRemoteURL:
            return "Invalid remote URL"
        case .invalidUpdateInterval:
            return "Update interval must be between \(Constants.minAutoUpdateInterval) and \(Constants.maxAutoUpdateInterval) hours"
        }
    }
}

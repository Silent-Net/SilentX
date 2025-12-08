//
//  RoutingRule.swift
//  SilentX
//
//  RoutingRule entity - represents a traffic routing rule
//

import Foundation
import SwiftData

/// Represents a traffic routing rule within a profile
@Model
final class RoutingRule {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// User-facing rule name
    var name: String
    
    /// Type of match criteria
    var matchType: RuleMatchType
    
    /// Value to match against
    var matchValue: String
    
    /// Action to take when matched
    var action: RuleAction
    
    /// Priority order (lower = higher priority)
    var order: Int
    
    /// Whether the rule is enabled
    var isEnabled: Bool
    
    /// Last updated timestamp
    var updatedAt: Date
    
    /// Creation timestamp
    var createdAt: Date
    
    // MARK: - Relationships
    
    /// Parent profile
    var profile: Profile?
    
    // MARK: - Initialization
    
    init(
        name: String,
        matchType: RuleMatchType,
        matchValue: String,
        action: RuleAction
    ) {
        self.id = UUID()
        self.name = name
        self.matchType = matchType
        self.matchValue = matchValue
        self.action = action
        self.order = 0
        self.isEnabled = true
        self.updatedAt = Date()
        self.createdAt = Date()
    }
    
    /// Convenience initializer without name for backward compatibility
    convenience init(
        matchType: RuleMatchType,
        matchValue: String,
        action: RuleAction
    ) {
        self.init(
            name: "\(matchType.displayName): \(matchValue)",
            matchType: matchType,
            matchValue: matchValue,
            action: action
        )
    }
    
    // MARK: - Computed Properties
    
    /// Alias for order for view compatibility
    var priority: Int {
        get { order }
        set { order = newValue }
    }
    
    /// Display string for the rule criteria
    var criteriaDisplay: String {
        "\(matchType.displayName): \(matchValue)"
    }
    
    /// Short description of the rule
    var shortDescription: String {
        "\(matchValue) → \(action.displayName)"
    }
}

// MARK: - Validation

extension RoutingRule {
    /// Validates the rule data
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuleValidationError.emptyName
        }
        
        guard name.count <= Constants.maxRuleNameLength else {
            throw RuleValidationError.nameTooLong
        }
        
        guard !matchValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuleValidationError.emptyMatchValue
        }
        
        try validateMatchValue()
    }
    
    /// Validates the match value based on match type
    private func validateMatchValue() throws {
        let value = matchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch matchType {
        case .domain, .domainSuffix, .domainKeyword:
            // Basic domain validation - just check it's not empty and has reasonable characters
            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
            guard value.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
                throw RuleValidationError.invalidDomainPattern
            }
            
        case .ipCIDR:
            // Basic CIDR validation
            let components = value.split(separator: "/")
            guard components.count == 2,
                  let prefix = Int(components[1]),
                  prefix >= 0 && prefix <= 128 else {
                throw RuleValidationError.invalidCIDR
            }
            
        case .geoIP:
            // GeoIP should be 2-letter country code
            guard value.count == 2,
                  value.allSatisfy({ $0.isLetter }) else {
                throw RuleValidationError.invalidGeoIPCode
            }
            
        case .process:
            // Process name - just check it's not too long and has reasonable characters
            guard value.count <= 255 else {
                throw RuleValidationError.invalidProcessName
            }
        }
    }
}

/// Rule validation errors
enum RuleValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case emptyMatchValue
    case invalidDomainPattern
    case invalidCIDR
    case invalidGeoIPCode
    case invalidProcessName
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Rule name cannot be empty"
        case .nameTooLong:
            return "Rule name is too long (max \(Constants.maxRuleNameLength) characters)"
        case .emptyMatchValue:
            return "Match value cannot be empty"
        case .invalidDomainPattern:
            return "Invalid domain pattern"
        case .invalidCIDR:
            return "Invalid CIDR notation (e.g., 192.168.1.0/24)"
        case .invalidGeoIPCode:
            return "Invalid GeoIP code (use 2-letter country code, e.g., US)"
        case .invalidProcessName:
            return "Invalid process name"
        }
    }
}

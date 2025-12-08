//
//  RuleService.swift
//  SilentX
//
//  Rule management service for CRUD operations and validation
//

import Foundation
import SwiftData
import Combine

/// Protocol for rule management operations
protocol RuleServiceProtocol {
    /// Creates a new routing rule
    func createRule(
        matchType: RuleMatchType,
        matchValue: String,
        action: RuleAction,
        context: ModelContext
    ) throws -> RoutingRule
    
    /// Deletes a routing rule
    func deleteRule(_ rule: RoutingRule, context: ModelContext) throws
    
    /// Validates rule configuration
    func validateRule(matchType: RuleMatchType, matchValue: String) -> RuleValidationResult
    
    /// Gets common rule templates
    func getTemplates() -> [RuleTemplate]
    
    /// Reorders rules to update priorities
    func reorderRules(_ rules: [RoutingRule], context: ModelContext) throws
}

/// Result of rule validation
struct RuleValidationResult {
    let isValid: Bool
    let errors: [String]
    
    static var valid: RuleValidationResult {
        RuleValidationResult(isValid: true, errors: [])
    }
    
    static func invalid(_ errors: [String]) -> RuleValidationResult {
        RuleValidationResult(isValid: false, errors: errors)
    }
}

/// Implementation of RuleService
@MainActor
final class RuleService: RuleServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = RuleService()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - CRUD Operations
    
    func createRule(
        matchType: RuleMatchType,
        matchValue: String,
        action: RuleAction,
        context: ModelContext
    ) throws -> RoutingRule {
        // Validate inputs
        let validation = validateRule(matchType: matchType, matchValue: matchValue)
        guard validation.isValid else {
            throw RuleError.invalidMatchValue(validation.errors.first ?? "Invalid match value")
        }
        
        // Get next priority
        let descriptor = FetchDescriptor<RoutingRule>(sortBy: [SortDescriptor(\.priority, order: .reverse)])
        let existingRules = try context.fetch(descriptor)
        let nextPriority = (existingRules.first?.priority ?? -1) + 1
        
        // Create and insert the rule
        let rule = RoutingRule(
            matchType: matchType,
            matchValue: matchValue.trimmingCharacters(in: .whitespaces),
            action: action
        )
        rule.priority = nextPriority
        
        context.insert(rule)
        try context.save()
        
        return rule
    }
    
    func deleteRule(_ rule: RoutingRule, context: ModelContext) throws {
        let deletedPriority = rule.priority
        
        context.delete(rule)
        try context.save()
        
        // Reorder remaining rules
        let descriptor = FetchDescriptor<RoutingRule>(
            predicate: #Predicate { $0.priority > deletedPriority },
            sortBy: [SortDescriptor(\.priority)]
        )
        let rulesToUpdate = try context.fetch(descriptor)
        
        for rule in rulesToUpdate {
            rule.priority -= 1
        }
        
        try context.save()
    }
    
    // MARK: - Validation
    
    func validateRule(matchType: RuleMatchType, matchValue: String) -> RuleValidationResult {
        let value = matchValue.trimmingCharacters(in: .whitespaces)
        var errors: [String] = []
        
        if value.isEmpty {
            errors.append("Match value cannot be empty")
            return .invalid(errors)
        }
        
        switch matchType {
        case .domain:
            if !isValidDomain(value) {
                errors.append("Invalid domain format")
            }
            
        case .domainSuffix:
            let domainValue = value.hasPrefix(".") ? String(value.dropFirst()) : value
            if !isValidDomain(domainValue) {
                errors.append("Invalid domain suffix format")
            }
            
        case .domainKeyword:
            if value.count < 2 {
                errors.append("Keyword must be at least 2 characters")
            }
            
        case .ipCIDR:
            if !isValidCIDR(value) {
                errors.append("Invalid CIDR notation (e.g., 192.168.1.0/24)")
            }
            
        case .geoIP:
            if !isValidCountryCode(value) {
                errors.append("Invalid country code (use 2-letter code like CN, US)")
            }
            
        case .process:
            if value.contains("/") || value.contains("\\") {
                errors.append("Process name should not include path")
            }
        }
        
        if errors.isEmpty {
            return .valid
        } else {
            return .invalid(errors)
        }
    }
    
    // MARK: - Templates
    
    func getTemplates() -> [RuleTemplate] {
        return RuleTemplatesSheet.defaultTemplates
    }
    
    // MARK: - Reordering
    
    func reorderRules(_ rules: [RoutingRule], context: ModelContext) throws {
        for (index, rule) in rules.enumerated() {
            rule.priority = index
        }
        try context.save()
    }
    
    // MARK: - Private Helpers
    
    private func isValidDomain(_ string: String) -> Bool {
        let pattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func isValidCIDR(_ string: String) -> Bool {
        let pattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
        guard string.range(of: pattern, options: .regularExpression) != nil else {
            return false
        }
        
        // Validate octets and prefix length
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let prefixLength = Int(parts[1]),
              prefixLength >= 0 && prefixLength <= 32 else {
            return false
        }
        
        let octets = parts[0].split(separator: ".")
        for octet in octets {
            guard let value = Int(octet), value >= 0 && value <= 255 else {
                return false
            }
        }
        
        return true
    }
    
    private func isValidCountryCode(_ string: String) -> Bool {
        return string.count == 2 && string.allSatisfy { $0.isLetter && $0.isUppercase }
    }
}

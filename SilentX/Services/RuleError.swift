//
//  RuleError.swift
//  SilentX
//
//  Rule-related errors with localized descriptions
//

import Foundation

/// Errors that can occur during rule operations
enum RuleError: LocalizedError {
    /// Match value is invalid for the selected type
    case invalidMatchValue(String)
    
    /// Match type is not supported
    case unsupportedMatchType
    
    /// Rule not found
    case notFound
    
    /// Duplicate rule exists
    case duplicateRule
    
    /// Priority conflict
    case priorityConflict
    
    /// Generic rule operation failure
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMatchValue(let detail):
            return "Invalid match value: \(detail)"
        case .unsupportedMatchType:
            return "This match type is not supported"
        case .notFound:
            return "Rule not found"
        case .duplicateRule:
            return "A rule with the same match condition already exists"
        case .priorityConflict:
            return "Rule priority conflict"
        case .operationFailed(let detail):
            return "Operation failed: \(detail)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidMatchValue:
            return "Check the format for this match type."
        case .unsupportedMatchType:
            return "Choose a supported match type."
        case .notFound:
            return "The rule may have been deleted."
        case .duplicateRule:
            return "Modify the existing rule or delete it first."
        case .priorityConflict:
            return "Try reordering the rules again."
        case .operationFailed:
            return "Try the operation again."
        }
    }
}

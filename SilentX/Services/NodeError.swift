//
//  NodeError.swift
//  SilentX
//
//  Node-related errors with localized descriptions
//

import Foundation

/// Errors that can occur during node operations
enum NodeError: LocalizedError {
    /// Node name is empty or invalid
    case invalidName(String)
    
    /// Server address is invalid
    case invalidServer(String)
    
    /// Port number is invalid
    case invalidPort(String)
    
    /// Protocol-specific credential is missing or invalid
    case invalidCredential(String)
    
    /// UUID format is invalid
    case invalidUUID
    
    /// Latency test failed
    case latencyTestFailed(String)
    
    /// Node not found
    case notFound
    
    /// Node already exists with this name
    case duplicateName
    
    /// Generic node operation failure
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName(let detail):
            return "Invalid node name: \(detail)"
        case .invalidServer(let detail):
            return "Invalid server address: \(detail)"
        case .invalidPort(let detail):
            return "Invalid port: \(detail)"
        case .invalidCredential(let detail):
            return "Invalid credential: \(detail)"
        case .invalidUUID:
            return "Invalid UUID format"
        case .latencyTestFailed(let detail):
            return "Latency test failed: \(detail)"
        case .notFound:
            return "Node not found"
        case .duplicateName:
            return "A node with this name already exists"
        case .operationFailed(let detail):
            return "Operation failed: \(detail)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Enter a valid node name."
        case .invalidServer:
            return "Enter a valid server address (domain or IP)."
        case .invalidPort:
            return "Enter a port number between 1 and 65535."
        case .invalidCredential:
            return "Check the credential format for this protocol."
        case .invalidUUID:
            return "Enter a valid UUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."
        case .latencyTestFailed:
            return "Check your network connection and server availability."
        case .notFound:
            return "The node may have been deleted."
        case .duplicateName:
            return "Choose a different name for the node."
        case .operationFailed:
            return "Try the operation again."
        }
    }
}

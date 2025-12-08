//
//  NodeService.swift
//  SilentX
//
//  Node management service for CRUD operations and latency testing
//

import Foundation
import SwiftData
import Combine

/// Protocol for node management operations
protocol NodeServiceProtocol {
    /// Creates a new proxy node
    func createNode(
        name: String,
        protocolType: ProxyProtocol,
        server: String,
        port: Int,
        context: ModelContext
    ) throws -> ProxyNode
    
    /// Deletes a proxy node
    func deleteNode(_ node: ProxyNode, context: ModelContext) throws
    
    /// Validates node configuration
    func validateNode(_ node: ProxyNode) -> NodeValidationResult
    
    /// Tests node latency (mock for MVP)
    func testLatency(_ node: ProxyNode, context: ModelContext) async throws -> Int
    
    /// Tests latency for multiple nodes
    func testLatency(nodes: [ProxyNode], context: ModelContext) async throws -> [UUID: Int]
}

/// Result of node validation
struct NodeValidationResult {
    let isValid: Bool
    let errors: [String]
    
    static var valid: NodeValidationResult {
        NodeValidationResult(isValid: true, errors: [])
    }
    
    static func invalid(_ errors: [String]) -> NodeValidationResult {
        NodeValidationResult(isValid: false, errors: errors)
    }
}

/// Implementation of NodeService
@MainActor
final class NodeService: NodeServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NodeService()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - CRUD Operations
    
    func createNode(
        name: String,
        protocolType: ProxyProtocol,
        server: String,
        port: Int,
        context: ModelContext
    ) throws -> ProxyNode {
        // Validate inputs
        guard !name.isEmpty else {
            throw NodeError.invalidName("Name cannot be empty")
        }
        
        guard !server.isEmpty else {
            throw NodeError.invalidServer("Server address cannot be empty")
        }
        
        guard port > 0 && port <= 65535 else {
            throw NodeError.invalidPort("Port must be between 1 and 65535")
        }
        
        // Create and insert the node
        let node = ProxyNode(
            name: name,
            protocolType: protocolType,
            server: server,
            port: port
        )
        
        context.insert(node)
        try context.save()
        
        return node
    }
    
    func deleteNode(_ node: ProxyNode, context: ModelContext) throws {
        context.delete(node)
        try context.save()
    }
    
    // MARK: - Validation
    
    func validateNode(_ node: ProxyNode) -> NodeValidationResult {
        var errors: [String] = []
        
        // Basic validation
        if node.name.isEmpty {
            errors.append("Name is required")
        }
        
        if node.server.isEmpty {
            errors.append("Server address is required")
        }
        
        if node.port <= 0 || node.port > 65535 {
            errors.append("Port must be between 1 and 65535")
        }
        
        // Protocol-specific validation
        switch node.protocolType {
        case .shadowsocks:
            if node.password == nil || node.password!.isEmpty {
                errors.append("Password is required for Shadowsocks")
            }
            if node.method == nil || node.method!.isEmpty {
                errors.append("Encryption method is required for Shadowsocks")
            }
            
        case .vmess, .vless:
            if node.uuid == nil || node.uuid!.isEmpty {
                errors.append("UUID is required for \(node.protocolType.displayName)")
            } else if let uuid = node.uuid, !isValidUUID(uuid) {
                errors.append("Invalid UUID format")
            }
            
        case .trojan:
            if node.password == nil || node.password!.isEmpty {
                errors.append("Password is required for Trojan")
            }
            
        case .hysteria2:
            if node.password == nil || node.password!.isEmpty {
                errors.append("Password is required for Hysteria2")
            }
            
        case .http, .socks5:
            // Username/password are optional
            break
        }
        
        // TLS validation
        if node.tls {
            if let sni = node.sni, !sni.isEmpty {
                if !isValidHostname(sni) {
                    errors.append("Invalid SNI format")
                }
            }
        }
        
        if errors.isEmpty {
            return .valid
        } else {
            return .invalid(errors)
        }
    }
    
    // MARK: - Latency Testing
    
    func testLatency(_ node: ProxyNode, context: ModelContext) async throws -> Int {
        // Mock implementation for MVP
        // In production, this would actually test connectivity to the server
        
        try await Task.sleep(nanoseconds: 200_000_000) // Simulate network delay
        
        let latency = Int.random(in: 50...500)
        node.latency = latency
        node.lastLatencyTest = Date()
        
        try context.save()
        
        return latency
    }
    
    func testLatency(nodes: [ProxyNode], context: ModelContext) async throws -> [UUID: Int] {
        var results: [UUID: Int] = [:]
        
        // In production, tests would run in parallel
        // For MVP, we test sequentially with mock data
        for node in nodes {
            let latency = try await testLatency(node, context: context)
            results[node.id] = latency
        }
        
        return results
    }
    
    // MARK: - Private Helpers
    
    private func isValidUUID(_ string: String) -> Bool {
        UUID(uuidString: string) != nil
    }
    
    private func isValidHostname(_ string: String) -> Bool {
        // Basic hostname validation
        let pattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }
}

//
//  ProxyNode.swift
//  SilentX
//
//  ProxyNode entity - represents a single proxy server endpoint
//

import Foundation
import SwiftData

/// Represents a single proxy server endpoint within a profile
@Model
final class ProxyNode {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// User-facing display name
    var name: String
    
    /// Server hostname or IP address
    var serverAddress: String
    
    /// Server port number
    var port: Int
    
    /// Proxy protocol type
    var protocolType: ProxyProtocol
    
    /// Encrypted protocol-specific credentials (JSON Data)
    var credentials: Data?
    
    /// Sort order within profile
    var order: Int
    
    /// Whether the node is enabled for use
    var isEnabled: Bool
    
    /// Last measured latency in milliseconds (nil if not tested)
    var latency: Int?
    
    /// Timestamp of last latency test
    var lastLatencyTest: Date?
    
    /// Creation timestamp
    var createdAt: Date
    
    // MARK: - Relationships
    
    /// Parent profile
    var profile: Profile?
    
    // MARK: - Initialization
    
    init(
        name: String,
        serverAddress: String,
        port: Int,
        protocolType: ProxyProtocol,
        credentials: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.serverAddress = serverAddress
        self.port = port
        self.protocolType = protocolType
        self.credentials = credentials
        self.order = 0
        self.isEnabled = true
        self.createdAt = Date()
    }
    
    /// Convenience initializer using server parameter name for view compatibility
    convenience init(
        name: String,
        protocolType: ProxyProtocol,
        server: String,
        port: Int
    ) {
        self.init(name: name, serverAddress: server, port: port, protocolType: protocolType)
    }
    
    // MARK: - Computed Properties
    
    /// Display string for server address and port
    var serverDisplay: String {
        "\(serverAddress):\(port)"
    }
    
    /// Latency display string
    var latencyDisplay: String {
        guard let latency = latency else {
            return "—"
        }
        return "\(latency) ms"
    }
    
    /// Whether latency is considered good (<100ms)
    var hasGoodLatency: Bool {
        guard let latency = latency else { return false }
        return latency < 100
    }
    
    /// Whether latency is considered medium (100-300ms)
    var hasMediumLatency: Bool {
        guard let latency = latency else { return false }
        return latency >= 100 && latency < 300
    }
    
    /// Whether latency is considered poor (>=300ms)
    var hasPoorLatency: Bool {
        guard let latency = latency else { return false }
        return latency >= 300
    }
}

// MARK: - Validation

extension ProxyNode {
    /// Validates the node data
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NodeValidationError.emptyName
        }
        
        guard name.count <= Constants.maxNodeNameLength else {
            throw NodeValidationError.nameTooLong
        }
        
        guard !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NodeValidationError.emptyServerAddress
        }
        
        guard Constants.validPortRange.contains(port) else {
            throw NodeValidationError.invalidPort
        }
        
        if protocolType.requiresCredentials && credentials == nil {
            throw NodeValidationError.missingCredentials
        }
    }
}

/// Node validation errors
enum NodeValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case emptyServerAddress
    case invalidPort
    case missingCredentials
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Node name cannot be empty"
        case .nameTooLong:
            return "Node name is too long (max \(Constants.maxNodeNameLength) characters)"
        case .emptyServerAddress:
            return "Server address cannot be empty"
        case .invalidPort:
            return "Port must be between 1 and 65535"
        case .missingCredentials:
            return "This protocol requires credentials"
        }
    }
}

// MARK: - Credentials

extension ProxyNode {
    /// Sets credentials from a dictionary
    func setCredentials(_ dict: [String: Any]) throws {
        credentials = try JSONSerialization.data(withJSONObject: dict)
    }
    
    /// Gets credentials as a dictionary
    func getCredentials() -> [String: Any]? {
        guard let data = credentials else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    private func getCredentialValue<T>(_ key: String) -> T? {
        getCredentials()?[key] as? T
    }
    
    private func setCredentialValue(_ key: String, _ value: Any?) {
        var creds = getCredentials() ?? [:]
        if let value = value {
            creds[key] = value
        } else {
            creds.removeValue(forKey: key)
        }
        try? setCredentials(creds)
    }
}

// MARK: - Convenience Properties for Views

extension ProxyNode {
    /// Alias for serverAddress for view compatibility
    var server: String {
        get { serverAddress }
        set { serverAddress = newValue }
    }
    
    /// Password stored in credentials
    var password: String? {
        get { getCredentialValue("password") }
        set { setCredentialValue("password", newValue) }
    }
    
    /// UUID stored in credentials
    var uuid: String? {
        get { getCredentialValue("uuid") }
        set { setCredentialValue("uuid", newValue) }
    }
    
    /// Encryption method stored in credentials
    var method: String? {
        get { getCredentialValue("method") }
        set { setCredentialValue("method", newValue) }
    }
    
    /// Alter ID stored in credentials
    var alterId: Int? {
        get { getCredentialValue("alterId") }
        set { setCredentialValue("alterId", newValue) }
    }
    
    /// Security setting stored in credentials
    var security: String? {
        get { getCredentialValue("security") }
        set { setCredentialValue("security", newValue) }
    }
    
    /// Username stored in credentials
    var username: String? {
        get { getCredentialValue("username") }
        set { setCredentialValue("username", newValue) }
    }
    
    /// Upload speed in Mbps stored in credentials
    var upMbps: Int? {
        get { getCredentialValue("upMbps") }
        set { setCredentialValue("upMbps", newValue) }
    }
    
    /// Download speed in Mbps stored in credentials
    var downMbps: Int? {
        get { getCredentialValue("downMbps") }
        set { setCredentialValue("downMbps", newValue) }
    }
    
    /// TLS enabled stored in credentials
    var tls: Bool {
        get { getCredentialValue("tls") ?? false }
        set { setCredentialValue("tls", newValue) }
    }
    
    /// SNI stored in credentials
    var sni: String? {
        get { getCredentialValue("sni") }
        set { setCredentialValue("sni", newValue) }
    }
    
    /// Skip certificate verification stored in credentials
    var skipCertVerify: Bool {
        get { getCredentialValue("skipCertVerify") ?? false }
        set { setCredentialValue("skipCertVerify", newValue) }
    }
    
    /// Last updated timestamp (for view compatibility)
    var updatedAt: Date? {
        get { lastLatencyTest }
        set { lastLatencyTest = newValue }
    }
}

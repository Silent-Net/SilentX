//
//  ConfigurationService.swift
//  SilentX
//
//  Configuration validation and parsing service
//

import Foundation
import Combine

/// Protocol for configuration validation and parsing
protocol ConfigurationServiceProtocol {
    /// Validates JSON configuration
    func validate(json: String) -> ConfigValidationResult
    
    /// Parses proxy nodes from JSON configuration
    func parseNodes(from json: String) throws -> [ParsedNode]
    
    /// Parses routing rules from JSON configuration
    func parseRules(from json: String) throws -> [ParsedRule]
    
    /// Generates Sing-Box JSON configuration from profile data
    func generateConfig(nodes: [ProxyNode], rules: [RoutingRule]) throws -> String
}

/// Result of configuration validation
struct ConfigValidationResult {
    let isValid: Bool
    let errors: [ConfigValidationError]
    let warnings: [ConfigValidationWarning]
    
    static var valid: ConfigValidationResult {
        ConfigValidationResult(isValid: true, errors: [], warnings: [])
    }
    
    static func invalid(_ errors: [ConfigValidationError]) -> ConfigValidationResult {
        ConfigValidationResult(isValid: false, errors: errors, warnings: [])
    }
}

/// Configuration validation error
struct ConfigValidationError: Identifiable {
    let id = UUID()
    let line: Int?
    let column: Int?
    let message: String
    let path: String?
    
    init(message: String, line: Int? = nil, column: Int? = nil, path: String? = nil) {
        self.message = message
        self.line = line
        self.column = column
        self.path = path
    }
}

/// Configuration validation warning
struct ConfigValidationWarning: Identifiable {
    let id = UUID()
    let message: String
    let suggestion: String?
}

/// Parsed node from JSON
struct ParsedNode {
    let tag: String
    let type: String
    let server: String
    let port: Int
    let rawJSON: [String: Any]
}

/// Parsed rule from JSON
struct ParsedRule {
    let matchType: String
    let matchValue: String
    let outbound: String
    let rawJSON: [String: Any]
}

/// Implementation of ConfigurationService
final class ConfigurationService: ConfigurationServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ConfigurationService()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Validation
    
    func validate(json: String) -> ConfigValidationResult {
        // First check if it's valid JSON
        guard let data = json.data(using: .utf8) else {
            return .invalid([ConfigValidationError(message: "Invalid UTF-8 encoding")])
        }
        
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let config = object as? [String: Any] else {
                return .invalid([ConfigValidationError(message: "Configuration must be a JSON object")])
            }
            
            var errors: [ConfigValidationError] = []
            var warnings: [ConfigValidationWarning] = []
            
            // Validate basic structure
            // Sing-Box config should have certain sections
            // For MVP, we do minimal validation
            
            // Check for recommended sections
            if config["outbounds"] == nil && config["endpoints"] == nil {
                warnings.append(ConfigValidationWarning(
                    message: "No outbounds or endpoints defined",
                    suggestion: "Add proxy server configuration"
                ))
            }
            
            // Check for inbounds (optional but common)
            if config["inbounds"] == nil {
                warnings.append(ConfigValidationWarning(
                    message: "No inbounds defined",
                    suggestion: "Add local proxy ports if needed"
                ))
            }
            
            // Validate outbounds if present
            if let outbounds = config["outbounds"] as? [[String: Any]] {
                for (index, outbound) in outbounds.enumerated() {
                    if outbound["tag"] == nil {
                        errors.append(ConfigValidationError(
                            message: "Outbound at index \(index) is missing 'tag'",
                            path: "outbounds[\(index)]"
                        ))
                    }
                    if outbound["type"] == nil {
                        errors.append(ConfigValidationError(
                            message: "Outbound at index \(index) is missing 'type'",
                            path: "outbounds[\(index)]"
                        ))
                    }
                }
            }
            
            // Validate route rules if present
            if let route = config["route"] as? [String: Any],
               let rules = route["rules"] as? [[String: Any]] {
                for (index, rule) in rules.enumerated() {
                    if rule["outbound"] == nil && rule["action"] == nil {
                        errors.append(ConfigValidationError(
                            message: "Rule at index \(index) is missing 'outbound' or 'action'",
                            path: "route.rules[\(index)]"
                        ))
                    }
                }
            }
            
            if errors.isEmpty {
                return ConfigValidationResult(isValid: true, errors: [], warnings: warnings)
            } else {
                return ConfigValidationResult(isValid: false, errors: errors, warnings: warnings)
            }
            
        } catch let error as NSError {
            // Parse JSON error for line/column info if available
            let errorMessage = error.localizedDescription
            return .invalid([ConfigValidationError(message: "JSON parse error: \(errorMessage)")])
        }
    }
    
    // MARK: - Parsing
    
    func parseNodes(from json: String) throws -> [ParsedNode] {
        guard let data = json.data(using: .utf8),
              let config = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigurationError.invalidJSON
        }
        
        var nodes: [ParsedNode] = []
        
        // Parse outbounds section
        if let outbounds = config["outbounds"] as? [[String: Any]] {
            for outbound in outbounds {
                guard let tag = outbound["tag"] as? String,
                      let type = outbound["type"] as? String else {
                    continue
                }
                
                // Skip built-in outbounds
                let builtInTypes = ["direct", "block", "dns", "selector", "urltest"]
                if builtInTypes.contains(type) {
                    continue
                }
                
                let server = outbound["server"] as? String ?? ""
                let port = outbound["server_port"] as? Int ?? 0
                
                nodes.append(ParsedNode(
                    tag: tag,
                    type: type,
                    server: server,
                    port: port,
                    rawJSON: outbound
                ))
            }
        }
        
        return nodes
    }
    
    func parseRules(from json: String) throws -> [ParsedRule] {
        guard let data = json.data(using: .utf8),
              let config = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigurationError.invalidJSON
        }
        
        var rules: [ParsedRule] = []
        
        // Parse route.rules section
        if let route = config["route"] as? [String: Any],
           let rulesList = route["rules"] as? [[String: Any]] {
            for rule in rulesList {
                let outbound = rule["outbound"] as? String ?? rule["action"] as? String ?? ""
                
                // Determine match type and value
                let matchTypes = ["domain", "domain_suffix", "domain_keyword", "domain_regex",
                                 "ip_cidr", "geoip", "geosite", "process_name", "process_path"]
                
                for matchType in matchTypes {
                    if let value = rule[matchType] {
                        let matchValue: String
                        if let stringValue = value as? String {
                            matchValue = stringValue
                        } else if let arrayValue = value as? [String] {
                            matchValue = arrayValue.joined(separator: ", ")
                        } else {
                            continue
                        }
                        
                        rules.append(ParsedRule(
                            matchType: matchType,
                            matchValue: matchValue,
                            outbound: outbound,
                            rawJSON: rule
                        ))
                        break
                    }
                }
            }
        }
        
        return rules
    }
    
    // MARK: - Generation
    
    func generateConfig(nodes: [ProxyNode], rules: [RoutingRule]) throws -> String {
        var config: [String: Any] = [:]
        
        // Generate outbounds from nodes
        var outbounds: [[String: Any]] = []
        
        for node in nodes {
            var outbound: [String: Any] = [
                "tag": node.name,
                "type": node.protocolType.rawValue,
                "server": node.server,
                "server_port": node.port
            ]
            
            // Add protocol-specific fields
            switch node.protocolType {
            case .shadowsocks:
                outbound["method"] = node.method ?? "aes-256-gcm"
                outbound["password"] = node.password ?? ""
                
            case .vmess, .vless:
                outbound["uuid"] = node.uuid ?? ""
                if let alterId = node.alterId {
                    outbound["alter_id"] = alterId
                }
                if let security = node.security {
                    outbound["security"] = security
                }
                
            case .trojan:
                outbound["password"] = node.password ?? ""
                
            case .hysteria2:
                outbound["password"] = node.password ?? ""
                if let upMbps = node.upMbps {
                    outbound["up_mbps"] = upMbps
                }
                if let downMbps = node.downMbps {
                    outbound["down_mbps"] = downMbps
                }
                
            case .http, .socks5:
                if let username = node.username {
                    outbound["username"] = username
                }
                if let password = node.password {
                    outbound["password"] = password
                }
            }
            
            // Add TLS settings if enabled
            if node.tls {
                var tlsConfig: [String: Any] = ["enabled": true]
                if let sni = node.sni {
                    tlsConfig["server_name"] = sni
                }
                if node.skipCertVerify {
                    tlsConfig["insecure"] = true
                }
                outbound["tls"] = tlsConfig
            }
            
            outbounds.append(outbound)
        }
        
        // Add built-in outbounds
        outbounds.append(["tag": "direct", "type": "direct"])
        outbounds.append(["tag": "block", "type": "block"])
        
        config["outbounds"] = outbounds
        
        // Generate route rules
        var routeRules: [[String: Any]] = []
        
        for rule in rules.sorted(by: { $0.priority < $1.priority }) {
            var ruleDict: [String: Any] = [
                "outbound": rule.action.rawValue
            ]
            
            // Add match condition
            switch rule.matchType {
            case .domain, .domainSuffix, .domainKeyword:
                ruleDict[rule.matchType.rawValue] = rule.matchValue
            case .ipCIDR:
                ruleDict["ip_cidr"] = rule.matchValue
            case .geoIP:
                ruleDict["geoip"] = rule.matchValue
            case .process:
                ruleDict["process_name"] = rule.matchValue
            }
            
            routeRules.append(ruleDict)
        }
        
        // Add final rule (direct)
        routeRules.append(["outbound": "direct"])
        
        config["route"] = ["rules": routeRules]
        
        // Serialize to JSON
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ConfigurationError.serializationFailed
        }
        
        return jsonString
    }
}

/// Configuration service errors
enum ConfigurationError: LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case serializationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .serializationFailed:
            return "Failed to generate JSON configuration"
        }
    }
}

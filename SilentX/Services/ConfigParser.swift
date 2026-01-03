//
//  ConfigParser.swift
//  SilentX
//
//  Parse sing-box configuration file to extract groups and their members
//  This maintains the exact order from the config file
//

import Foundation
import OSLog

/// Parser for sing-box configuration files
/// Extracts outbound groups while preserving the original order from the config
struct ConfigParser {
    
    // MARK: - Types
    
    /// Group types that can contain other outbounds
    static let groupTypes: Set<String> = ["selector", "urltest", "fallback", "loadbalance"]
    
    /// Outbound entry from config
    struct OutboundEntry {
        let tag: String
        let type: String
        let outbounds: [String]?  // Members (for groups)
        let defaultOutbound: String?  // Default selection (for selector)
    }
    
    /// Parsed result
    struct ParseResult {
        /// Groups in config order
        let groups: [OutboundGroup]
        /// All outbound tags for lookup
        let allOutbounds: [String: OutboundEntry]
    }
    
    // MARK: - Private
    
    private static let logger = Logger(subsystem: "com.silentnet.silentx", category: "ConfigParser")
    
    // MARK: - Public Methods
    
    /// Parse groups from a config file URL
    static func parseGroups(from configURL: URL) throws -> ParseResult {
        let data = try Data(contentsOf: configURL)
        return try parseGroups(from: data)
    }
    
    /// Parse groups from JSON data
    static func parseGroups(from data: Data) throws -> ParseResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = json["outbounds"] as? [[String: Any]] else {
            throw ConfigParserError.invalidFormat("Missing or invalid 'outbounds' array")
        }
        
        return parseOutbounds(outbounds)
    }
    
    /// Parse groups from JSON string
    static func parseGroups(from jsonString: String) throws -> ParseResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ConfigParserError.invalidFormat("Invalid UTF-8 string")
        }
        return try parseGroups(from: data)
    }
    
    // MARK: - Private Methods
    
    private static func parseOutbounds(_ outbounds: [[String: Any]]) -> ParseResult {
        var allEntries: [String: OutboundEntry] = [:]
        var groups: [OutboundGroup] = []
        
        // First pass: collect all outbound entries
        for outbound in outbounds {
            guard let tag = outbound["tag"] as? String,
                  let type = outbound["type"] as? String else {
                continue
            }
            
            let members = outbound["outbounds"] as? [String]
            let defaultOutbound = outbound["default"] as? String
            
            let entry = OutboundEntry(
                tag: tag,
                type: type,
                outbounds: members,
                defaultOutbound: defaultOutbound
            )
            allEntries[tag] = entry
        }
        
        // Second pass: build groups in order
        for outbound in outbounds {
            guard let tag = outbound["tag"] as? String,
                  let type = outbound["type"] as? String else {
                continue
            }
            
            // Skip non-group types
            guard groupTypes.contains(type.lowercased()) else {
                continue
            }
            
            // Skip special groups
            if tag == "GLOBAL" || tag == "DIRECT" || tag == "REJECT" {
                continue
            }
            
            guard let members = outbound["outbounds"] as? [String] else {
                continue
            }
            
            // Build items from members
            let items = members.enumerated().compactMap { (index, memberTag) -> OutboundGroupItem? in
                let memberEntry = allEntries[memberTag]
                let memberType = memberEntry?.type ?? "Unknown"
                
                // Determine if this is the default/selected
                let defaultOutbound = outbound["default"] as? String
                let isSelected = (defaultOutbound == memberTag) || (index == 0 && defaultOutbound == nil)
                
                return OutboundGroupItem(
                    id: memberTag,
                    tag: memberTag,
                    type: memberType,
                    delay: nil,
                    isSelected: isSelected
                )
            }
            
            // Determine selectability based on type
            let isSelectable = type.lowercased() == "selector"
            
            // Get current selection (default or first)
            let defaultOutbound = outbound["default"] as? String
            let selected = defaultOutbound ?? members.first ?? ""
            
            let group = OutboundGroup(
                id: tag,
                tag: tag,
                type: type,
                selected: selected,
                selectable: isSelectable,
                items: items
            )
            
            groups.append(group)
        }
        
        return ParseResult(groups: groups, allOutbounds: allEntries)
    }
}

// MARK: - Errors

enum ConfigParserError: LocalizedError {
    case invalidFormat(String)
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let detail):
            return "Invalid config format: \(detail)"
        case .fileNotFound(let path):
            return "Config file not found: \(path)"
        }
    }
}

//
//  OutboundGroup.swift
//  SilentX
//
//  Models for proxy groups from Clash API
//

import Foundation
import SwiftUI

/// Represents a proxy group (selector, urltest, etc.)
struct OutboundGroup: Identifiable, Hashable {
    let id: String
    let tag: String           // "Hong Kong", "NodeSelected"
    let type: String          // "Selector", "URLTest", "Direct"
    var selected: String      // Currently selected node tag
    let selectable: Bool      // Can user manually select node (true for selector type only)
    var items: [OutboundGroupItem]
    var isExpanded: Bool = true
    
    /// Whether this group allows manual node selection
    /// Note: This is derived from the 'selectable' property from Clash API
    var isSelectable: Bool {
        selectable
    }
    
    /// Icon for the group type
    var typeIcon: String {
        switch type.lowercased() {
        case "selector":
            return "checklist"
        case "urltest":
            return "speedometer"
        case "fallback":
            return "arrow.triangle.branch"
        case "loadbalance":
            return "circle.grid.cross"
        case "direct":
            return "arrow.right"
        case "reject", "block":
            return "xmark.circle"
        default:
            return "globe"
        }
    }
    
    /// Display name for the group type
    var typeDisplayName: String {
        switch type.lowercased() {
        case "selector":
            return "Selector"
        case "urltest":
            return "URL Test"
        case "fallback":
            return "Fallback"
        case "loadbalance":
            return "Load Balance"
        case "direct":
            return "Direct"
        case "reject", "block":
            return "Reject"
        default:
            return type
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(selected)
        hasher.combine(items)
    }
    
    static func == (lhs: OutboundGroup, rhs: OutboundGroup) -> Bool {
        lhs.id == rhs.id &&
        lhs.selected == rhs.selected &&
        lhs.items == rhs.items
    }
}

/// Represents a single node within a proxy group
struct OutboundGroupItem: Identifiable, Hashable {
    let id: String
    let tag: String           // "HK-01", "JP-Tokyo"
    let type: String          // "Trojan", "Shadowsocks", etc.
    var delay: Int?           // Latency in ms, nil = not tested
    var isSelected: Bool
    var isTesting: Bool = false
    
    /// Color based on latency
    var delayColor: Color {
        guard let delay else { return .secondary }
        if delay <= 0 { return .red } // Timeout or error
        if delay < 300 { return .green }
        if delay < 600 { return .yellow }
        return .red
    }
    
    /// Formatted delay text
    var delayText: String {
        guard let delay else { return "" }
        if delay <= 0 { return "Timeout" }
        return "\(delay)ms"
    }
    
    /// Icon for the proxy type
    var typeIcon: String {
        switch type.lowercased() {
        case "trojan":
            return "shield"
        case "shadowsocks", "ss":
            return "lock.shield"
        case "vmess":
            return "v.circle"
        case "vless":
            return "v.square"
        case "hysteria", "hysteria2":
            return "bolt.shield"
        case "direct":
            return "arrow.right"
        case "reject", "block":
            return "xmark.circle"
        case "selector":
            return "checklist"
        case "urltest":
            return "speedometer"
        default:
            return "globe"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(delay)
        hasher.combine(isSelected)
        hasher.combine(isTesting)
    }
    
    static func == (lhs: OutboundGroupItem, rhs: OutboundGroupItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.delay == rhs.delay &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isTesting == rhs.isTesting
    }
}

// MARK: - Clash API Response Types

/// Root response from GET /proxies
/// Uses custom parsing to preserve key order from JSON
struct ClashProxiesResponse {
    let proxies: [String: ClashProxyInfo]
    /// Ordered keys from the original JSON (preserves config file order)
    let orderedKeys: [String]
}

/// Individual proxy/group info from Clash API
struct ClashProxyInfo: Codable {
    let type: String
    let now: String?           // Current selection (for groups)
    let all: [String]?         // All members (for groups)
    let history: [ClashDelayHistory]?
    
    /// Whether this proxy/group allows manual selection
    /// Only "selector" type groups allow manual switching
    var selectable: Bool {
        type.lowercased() == "selector"
    }
    
    /// Most recent delay from history
    var latestDelay: Int? {
        history?.last?.delay
    }
}

/// Delay history entry
struct ClashDelayHistory: Codable {
    let time: String?
    let delay: Int
}

/// Response from GET /proxies/:name/delay
struct ClashDelayResponse: Codable {
    let delay: Int?
    let message: String?
}

//
//  RuleAction.swift
//  SilentX
//
//  Routing rule action enumeration
//

import Foundation
import SwiftUI

/// Actions that can be taken when a routing rule matches
enum RuleAction: String, Codable, CaseIterable, Identifiable {
    case proxy = "proxy"
    case direct = "direct"
    case block = "reject"
    
    var id: String { rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .proxy: return "Proxy"
        case .direct: return "Direct"
        case .block: return "Block"
        }
    }
    
    /// Description of the action
    var description: String {
        switch self {
        case .proxy: return "Route through proxy server"
        case .direct: return "Connect directly (bypass proxy)"
        case .block: return "Block connection"
        }
    }
    
    /// SF Symbol name for the action
    var systemImage: String {
        switch self {
        case .proxy: return "arrow.triangle.branch"
        case .direct: return "arrow.right"
        case .block: return "xmark.circle"
        }
    }
    
    /// Color associated with the action
    var color: Color {
        switch self {
        case .proxy: return .blue
        case .direct: return .green
        case .block: return .red
        }
    }
}

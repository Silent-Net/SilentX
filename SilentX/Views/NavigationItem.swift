//
//  NavigationItem.swift
//  SilentX
//
//  Navigation items for sidebar navigation
//

import SwiftUI

/// Navigation items for the sidebar
enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case groups = "Groups"
    case profiles = "Profiles"
    case nodes = "Nodes"
    case rules = "Rules"
    case logs = "Logs"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    /// SF Symbol name for the item
    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .groups: return "rectangle.3.group"
        case .profiles: return "doc.text"
        case .nodes: return "server.rack"
        case .rules: return "arrow.triangle.branch"
        case .logs: return "text.alignleft"
        case .settings: return "gearshape"
        }
    }
    
    /// Keyboard shortcut for the item
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .dashboard: return "1"
        case .groups: return "2"
        case .profiles: return "3"
        case .nodes: return "4"
        case .rules: return "5"
        case .logs: return "6"
        case .settings: return ","
        }
    }
    
    /// Whether this item should be in the main section
    var isMainSection: Bool {
        switch self {
        case .dashboard, .groups, .profiles, .nodes, .rules, .logs:
            return true
        case .settings:
            return false
        }
    }
}

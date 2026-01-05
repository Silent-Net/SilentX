//
//  LogLevel.swift
//  SilentX
//
//  Log level enumeration for categorizing log entries
//

import Foundation
import SwiftUI

/// Log severity levels
enum LogLevel: String, CaseIterable, Codable {
    case trace = "trace"
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fatal = "fatal"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var iconName: String {
        switch self {
        case .trace: return "text.magnifyingglass"
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .fatal: return "xmark.octagon"
        }
    }
    
    var color: Color {
        switch self {
        case .trace: return .gray
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .fatal: return .purple
        }
    }
    
    /// Text color for log messages (less saturated than icon color)
    var textColor: Color {
        switch self {
        case .trace, .debug, .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .fatal: return .purple
        }
    }
    
    /// Severity order for filtering (higher = more severe)
    var severity: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .fatal: return 5
        }
    }
}

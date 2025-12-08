//
//  LogEntry.swift
//  SilentX
//
//  Log entry struct representing a single log message
//

import Foundation

/// Represents a single log entry
struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let source: String?
    
    init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: String,
        message: String,
        source: String? = nil
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.source = source
    }
    
    /// Formatted timestamp for display
    var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .standard)
    }
    
    /// Full formatted timestamp
    var formattedDateTime: String {
        timestamp.formatted(date: .abbreviated, time: .standard)
    }
}

/// Common log categories
enum LogCategory {
    static let connection = "Connection"
    static let proxy = "Proxy"
    static let dns = "DNS"
    static let route = "Route"
    static let tun = "TUN"
    static let core = "Core"
    static let config = "Config"
    static let system = "System"
    
    static let allCategories = [connection, proxy, dns, route, tun, core, config, system]
}

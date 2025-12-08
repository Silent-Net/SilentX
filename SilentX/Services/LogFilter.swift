//
//  LogFilter.swift
//  SilentX
//
//  Log filter struct for filtering log entries
//

import Foundation

/// Filter configuration for log entries
struct LogFilter {
    var minLevel: LogLevel
    var categories: Set<String>
    var searchText: String
    
    init(
        minLevel: LogLevel = .debug,
        categories: Set<String> = [],
        searchText: String = ""
    ) {
        self.minLevel = minLevel
        self.categories = categories
        self.searchText = searchText
    }
    
    /// Creates a filter that shows all logs
    static var all: LogFilter {
        LogFilter(minLevel: .trace, categories: [], searchText: "")
    }
    
    /// Filters an array of log entries
    func apply(to entries: [LogEntry]) -> [LogEntry] {
        entries.filter { entry in
            // Filter by level
            guard entry.level.severity >= minLevel.severity else {
                return false
            }
            
            // Filter by category
            if !categories.isEmpty && !categories.contains(entry.category) {
                return false
            }
            
            // Filter by search text
            if !searchText.isEmpty {
                let lowerSearch = searchText.lowercased()
                let matches = entry.message.lowercased().contains(lowerSearch) ||
                              entry.category.lowercased().contains(lowerSearch) ||
                              (entry.source?.lowercased().contains(lowerSearch) ?? false)
                if !matches {
                    return false
                }
            }
            
            return true
        }
    }
}

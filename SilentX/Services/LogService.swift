//
//  LogService.swift
//  SilentX
//
//  Log service for managing and streaming log entries
//

import Foundation
import Combine
import os

extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "SilentX"
    
    static let system = Logger(subsystem: subsystem, category: "system")
    static let connection = Logger(subsystem: subsystem, category: "connection")
    static let proxy = Logger(subsystem: subsystem, category: "proxy")
    static let core = Logger(subsystem: subsystem, category: "core")
    static let config = Logger(subsystem: subsystem, category: "config")
    static let dns = Logger(subsystem: subsystem, category: "dns")
    static let route = Logger(subsystem: subsystem, category: "route")
    static let tun = Logger(subsystem: subsystem, category: "tun")
    
    /// Log with redaction for sensitive data
    func logSecure(_ message: String, level: OSLogType = .info) {
        self.log(level: level, "\(message, privacy: .private)")
    }
    
    /// Log credentials or tokens with full redaction
    func logRedacted(_ label: String, value: String) {
        self.log(level: .debug, "\(label, privacy: .public): <redacted>")
    }
}

/// Protocol for log service operations
protocol LogServiceProtocol: ObservableObject {
    /// Current log entries
    var entries: [LogEntry] { get }
    
    /// Publisher for new log entries
    var entryPublisher: AnyPublisher<LogEntry, Never> { get }
    
    /// Clears all log entries
    func clear()
    
    /// Exports logs to a file
    func export(to url: URL) throws
    
    /// Starts log collection
    func start()
    
    /// Stops log collection
    func stop()
}

/// Mock implementation of LogService for MVP development
@MainActor
final class LogService: LogServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var entries: [LogEntry] = []
    
    // MARK: - Private Properties
    
    private let entrySubject = PassthroughSubject<LogEntry, Never>()
    private var mockTimer: Timer?
    private var isRunning = false
    
    // MARK: - Public Properties
    
    var entryPublisher: AnyPublisher<LogEntry, Never> {
        entrySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() {
        // Add some initial mock entries
        addInitialLogs()
    }
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // Start mock log generation
        mockTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.generateMockLog()
            }
        }
    }
    
    func stop() {
        isRunning = false
        mockTimer?.invalidate()
        mockTimer = nil
    }
    
    func clear() {
        entries.removeAll()
    }
    
    func export(to url: URL) throws {
        var content = "SilentX Log Export\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Entries: \(entries.count)\n"
        content += String(repeating: "=", count: 60) + "\n\n"
        
        for entry in entries {
            let line = "[\(entry.formattedDateTime)] [\(entry.level.displayName.uppercased())] [\(entry.category)] \(entry.message)"
            content += line + "\n"
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Private Methods
    
    private func addInitialLogs() {
        let initialLogs: [(LogLevel, String, String)] = [
            (.info, LogCategory.system, "SilentX started"),
            (.info, LogCategory.core, "Sing-Box core version 1.9.0"),
            (.debug, LogCategory.config, "Configuration loaded successfully"),
            (.info, LogCategory.system, "Ready to connect"),
        ]
        
        for (index, log) in initialLogs.enumerated() {
            let entry = LogEntry(
                timestamp: Date().addingTimeInterval(Double(-initialLogs.count + index)),
                level: log.0,
                category: log.1,
                message: log.2
            )
            entries.append(entry)
        }
    }
    
    private func generateMockLog() {
        let mockLogs: [(LogLevel, String, String)] = [
            (.debug, LogCategory.proxy, "Outbound connection established to proxy server"),
            (.info, LogCategory.connection, "New TCP connection from 127.0.0.1:52341"),
            (.debug, LogCategory.dns, "DNS query: google.com -> 142.250.189.206"),
            (.trace, LogCategory.route, "Route matched: domain google.com -> proxy"),
            (.debug, LogCategory.proxy, "Upstream latency: 45ms"),
            (.info, LogCategory.dns, "DNS cache hit: github.com"),
            (.warning, LogCategory.tun, "TUN device write buffer full, dropping packet"),
            (.debug, LogCategory.connection, "Connection closed: 127.0.0.1:52341"),
            (.info, LogCategory.core, "Statistics: ↑ 1.2 MB ↓ 5.6 MB"),
            (.trace, LogCategory.route, "Final rule matched: direct"),
        ]
        
        let randomLog = mockLogs.randomElement()!
        let entry = LogEntry(
            level: randomLog.0,
            category: randomLog.1,
            message: randomLog.2
        )
        
        entries.append(entry)
        entrySubject.send(entry)
        
        // Limit entries to prevent memory issues
        if entries.count > 1000 {
            entries.removeFirst(100)
        }
    }
}

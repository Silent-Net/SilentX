//
//  LogService.swift
//  SilentX
//
//  Log service for streaming real logs from sing-box Clash API
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

/// Real LogService that connects to sing-box Clash API WebSocket
@MainActor
final class LogService: LogServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isRunning: Bool = false
    
    // MARK: - Private Properties
    
    private let entrySubject = PassthroughSubject<LogEntry, Never>()
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    
    // Clash API configuration
    private var clashAPIPort: Int = 9090
    
    // MARK: - Public Properties
    
    var entryPublisher: AnyPublisher<LogEntry, Never> {
        entrySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() {
        // Add startup log
        addSystemLog("SilentX Log Viewer started")
    }
    
    deinit {
        reconnectTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func start() {
        let wasRunning = isRunning
        guard !isRunning else { return }
        isRunning = true
        
        // Try to get the actual port from ConnectionService
        if let port = ConnectionService.shared.clashAPIPort {
            clashAPIPort = port
        }
        
        // Only show resume message if this was a resume (not initial start)
        if wasRunning == false && entries.count > 1 {
            addSystemLog("Log capture resumed", level: .info)
        }
        
        connectWebSocket()
    }
    
    func stop() {
        isRunning = false
        reconnectTask?.cancel()
        disconnectWebSocket()
        addSystemLog("Log capture paused", level: .info)
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
    
    // MARK: - WebSocket Connection
    
    private func connectWebSocket() {
        // Disconnect existing connection first
        disconnectWebSocket()
        
        // Build WebSocket URL for sing-box logs
        // Format: ws://localhost:9090/logs?level=debug
        guard let url = URL(string: "ws://127.0.0.1:\(clashAPIPort)/logs?level=debug") else {
            addSystemLog("Invalid WebSocket URL", level: .error)
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        addSystemLog("Connected to sing-box log stream")
        
        // Start receiving messages
        receiveMessage()
    }
    
    private func disconnectWebSocket() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self, self.isRunning else { return }
                
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    // Continue receiving
                    self.receiveMessage()
                    
                case .failure(let error):
                    self.isConnected = false
                    self.addSystemLog("WebSocket error: \(error.localizedDescription)", level: .warning)
                    // Try to reconnect after delay
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseLogMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseLogMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    /// Parse sing-box log message JSON
    /// Format: {"type":"info","payload":"[2465771203 2ms] outbound/trojan[🇭🇰 Gold-香港]: outbound connection to 1.2.3.4:443"}
    private func parseLogMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String,
               let payload = json["payload"] as? String {
                
                let level = parseLogLevel(type)
                let (category, message) = parsePayload(payload)
                
                let entry = LogEntry(
                    level: level,
                    category: category,
                    message: message
                )
                
                entries.append(entry)
                entrySubject.send(entry)
                
                // Limit entries to prevent memory issues
                if entries.count > 2000 {
                    entries.removeFirst(500)
                }
            }
        } catch {
            // If not JSON, treat as raw log
            let entry = LogEntry(
                level: .debug,
                category: LogCategory.core,
                message: text
            )
            entries.append(entry)
            entrySubject.send(entry)
        }
    }
    
    private func parseLogLevel(_ type: String) -> LogLevel {
        switch type.lowercased() {
        case "trace": return .trace
        case "debug": return .debug
        case "info": return .info
        case "warn", "warning": return .warning
        case "error": return .error
        case "fatal", "panic": return .fatal
        default: return .info
        }
    }
    
    /// Parse sing-box log payload to extract category and message
    /// Example: "[2465771203 2ms] outbound/trojan[🇭🇰 Gold-香港]: outbound connection to 1.2.3.4:443"
    private func parsePayload(_ payload: String) -> (String, String) {
        var message = payload
        var category = LogCategory.core
        
        // Try to extract category from patterns like "outbound/trojan", "inbound/tun", "router:"
        if payload.contains("outbound/") {
            category = LogCategory.proxy
        } else if payload.contains("inbound/") {
            category = LogCategory.connection
        } else if payload.contains("router:") || payload.contains("route") {
            category = LogCategory.route
        } else if payload.contains("dns") || payload.contains("DNS") {
            category = LogCategory.dns
        } else if payload.contains("tun") || payload.contains("TUN") {
            category = LogCategory.tun
        }
        
        return (category, message)
    }
    
    private func scheduleReconnect() {
        guard isRunning else { return }
        
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            guard let self = self, self.isRunning else { return }
            await MainActor.run {
                self.addSystemLog("Attempting to reconnect...")
                self.connectWebSocket()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addSystemLog(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(
            level: level,
            category: LogCategory.system,
            message: message
        )
        entries.append(entry)
        entrySubject.send(entry)
    }
}

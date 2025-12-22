//
//  IPCTypes.swift
//  SilentX
//
//  Shared IPC types for communication between main app and privileged helper service
//

import Foundation

// MARK: - IPCCommand (T005)

/// Commands supported by the IPC protocol
enum IPCCommand: String, Codable, CaseIterable {
    /// Get service version information
    case version
    
    /// Start sing-box with provided configuration
    case start
    
    /// Stop running sing-box process
    case stop
    
    /// Get current status of the service and sing-box
    case status
    
    /// Get recent log output from sing-box
    case logs
    
    /// Heartbeat check - verify service is responsive
    case ping
}

// MARK: - IPCRequest (T006)

/// Request message sent from main app to service over Unix socket
struct IPCRequest: Codable {
    /// Command to execute
    let cmd: IPCCommand
    
    /// Path to sing-box configuration file (required for `start` command)
    var configPath: String?
    
    /// Path to sing-box binary (required for `start` command)
    var corePath: String?
    
    /// Optional authentication token (reserved for future use)
    var authToken: String?

    /// Optional system proxy settings to apply while running (optional)
    /// Used primarily for TUN configs that rely on platform.http_proxy.
    var systemProxy: SystemProxySettings?
    
    enum CodingKeys: String, CodingKey {
        case cmd
        case configPath = "config_path"
        case corePath = "core_path"
        case authToken = "auth_token"
        case systemProxy = "system_proxy"
    }
    
    // MARK: - Factory Methods
    
    /// Create a ping request
    static func ping() -> IPCRequest {
        IPCRequest(cmd: .ping)
    }
    
    /// Create a version request
    static func version() -> IPCRequest {
        IPCRequest(cmd: .version)
    }
    
    /// Create a start request
    static func start(configPath: String, corePath: String, systemProxy: SystemProxySettings? = nil) -> IPCRequest {
        IPCRequest(cmd: .start, configPath: configPath, corePath: corePath, authToken: nil, systemProxy: systemProxy)
    }
    
    /// Create a stop request
    static func stop() -> IPCRequest {
        IPCRequest(cmd: .stop)
    }
    
    /// Create a status request
    static func status() -> IPCRequest {
        IPCRequest(cmd: .status)
    }
    
    /// Create a logs request
    static func logs() -> IPCRequest {
        IPCRequest(cmd: .logs)
    }
}

// MARK: - SystemProxySettings

/// System proxy settings to apply for the duration of a sing-box session.
/// Implemented by the privileged helper service (root) via `networksetup`.
struct SystemProxySettings: Codable, Equatable {
    /// Enable or disable proxy settings.
    let enabled: Bool

    /// Proxy server host (e.g. 127.0.0.1)
    let host: String

    /// Proxy server port
    let port: Int

    /// Optional bypass domains (e.g. ["localhost", "127.0.0.1"])
    let bypassDomains: [String]?
}

// MARK: - IPCResponse (T007)

/// Response message sent from service to main app
struct IPCResponse: Codable {
    /// Status code (0 = success, >0 = error)
    let code: Int
    
    /// Human-readable message
    let message: String
    
    /// Command-specific response data (JSON encoded)
    let data: AnyCodableData?
    
    /// Check if response indicates success
    var isSuccess: Bool {
        code == IPCErrorCode.success.rawValue
    }
    
    /// Get error code enum
    var errorCode: IPCErrorCode {
        IPCErrorCode(rawValue: code) ?? .unknownError
    }
    
    // MARK: - Factory Methods
    
    /// Create a success response
    static func success(message: String = "OK", data: AnyCodableData? = nil) -> IPCResponse {
        IPCResponse(code: IPCErrorCode.success.rawValue, message: message, data: data)
    }
    
    /// Create an error response
    static func error(_ code: IPCErrorCode, message: String) -> IPCResponse {
        IPCResponse(code: code.rawValue, message: message, data: nil)
    }
}

/// Wrapper for type-erased Codable data in responses
struct AnyCodableData: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodableData].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableData].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodableData")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int32 as Int32:
            try container.encode(Int(int32))
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodableData($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableData($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value of type \(type(of: value))"))
        }
    }
}

// MARK: - IPCErrorCode

/// Error codes for IPC responses
enum IPCErrorCode: Int, CaseIterable {
    /// Operation completed successfully
    case success = 0
    
    /// Unexpected error occurred
    case unknownError = 1
    
    /// Unrecognized command
    case invalidCommand = 2
    
    /// Missing or invalid parameters
    case invalidParams = 3
    
    /// Attempted start when already running
    case coreAlreadyRunning = 4
    
    /// Attempted stop when not running
    case coreNotRunning = 5
    
    /// Failed to start sing-box process
    case coreStartFailed = 6
    
    /// Config file does not exist
    case configNotFound = 7
    
    /// Core binary does not exist
    case coreNotFound = 8
    
    /// Operation not permitted
    case permissionDenied = 9
    
    /// Human-readable description
    var description: String {
        switch self {
        case .success: return "Success"
        case .unknownError: return "Unknown error"
        case .invalidCommand: return "Invalid command"
        case .invalidParams: return "Invalid parameters"
        case .coreAlreadyRunning: return "Core already running"
        case .coreNotRunning: return "Core not running"
        case .coreStartFailed: return "Failed to start core"
        case .configNotFound: return "Configuration file not found"
        case .coreNotFound: return "Core binary not found"
        case .permissionDenied: return "Permission denied"
        }
    }
}

// MARK: - StatusData (T008)

/// Status data returned by the `status` command
struct StatusData: Codable {
    /// Whether sing-box is currently running
    let isRunning: Bool
    
    /// Process ID of running sing-box (nil if not running)
    let pid: Int32?
    
    /// Path to the active configuration file (nil if not running)
    let configPath: String?
    
    /// When sing-box was started (nil if not running)
    let startTime: Date?
    
    /// Uptime in seconds (nil if not running)
    let uptimeSeconds: Int?
    
    /// Last exit code if process crashed (T068)
    let lastExitCode: Int32?
    
    /// Error/crash reason if process crashed (T068)
    let errorReason: String?
    
    enum CodingKeys: String, CodingKey {
        case isRunning = "is_running"
        case pid
        case configPath = "config_path"
        case startTime = "start_time"
        case uptimeSeconds = "uptime_seconds"
        case lastExitCode = "last_exit_code"
        case errorReason = "error_reason"
    }
    
    /// Create status for running state
    static func running(pid: Int32, configPath: String, startTime: Date) -> StatusData {
        let uptime = Int(Date().timeIntervalSince(startTime))
        return StatusData(
            isRunning: true,
            pid: pid,
            configPath: configPath,
            startTime: startTime,
            uptimeSeconds: uptime,
            lastExitCode: nil,
            errorReason: nil
        )
    }
    
    /// Create status for stopped state
    static func stopped() -> StatusData {
        StatusData(
            isRunning: false,
            pid: nil,
            configPath: nil,
            startTime: nil,
            uptimeSeconds: nil,
            lastExitCode: nil,
            errorReason: nil
        )
    }
    
    /// Create status for crashed state (T068)
    static func crashed(exitCode: Int32, reason: String?) -> StatusData {
        StatusData(
            isRunning: false,
            pid: nil,
            configPath: nil,
            startTime: nil,
            uptimeSeconds: nil,
            lastExitCode: exitCode,
            errorReason: reason
        )
    }
}

// MARK: - VersionData (T009)

/// Version data returned by the `version` command
struct VersionData: Codable {
    /// Service version string
    let version: String
    
    /// Build date string (optional)
    let buildDate: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case buildDate = "build_date"
    }
}

// MARK: - LogsData

/// Logs data returned by the `logs` command
struct LogsData: Codable {
    /// Recent log lines
    let lines: [String]
    
    /// Total number of lines available
    let totalLines: Int
    
    enum CodingKeys: String, CodingKey {
        case lines
        case totalLines = "total_lines"
    }
}

// MARK: - StartData

/// Data returned by the `start` command on success
struct StartData: Codable {
    /// Process ID of the started sing-box
    let pid: Int32
}

// MARK: - Typed Response Helpers

extension IPCResponse {
    /// Decode data as StatusData
    func asStatusData() -> StatusData? {
        guard let data = data else { return nil }
        guard let dict = data.value as? [String: Any] else { return nil }
        
        // Manual decoding since we have type-erased data
        let isRunning = dict["is_running"] as? Bool ?? false
        let pid = (dict["pid"] as? Int).map { Int32($0) }
        let configPath = dict["config_path"] as? String
        let uptimeSeconds = dict["uptime_seconds"] as? Int
        let lastExitCode = dict["last_exit_code"] as? Int32
        let errorReason = dict["error_reason"] as? String
        
        // Parse start_time if present
        var startTime: Date? = nil
        if let startTimeString = dict["start_time"] as? String {
            let formatter = ISO8601DateFormatter()
            startTime = formatter.date(from: startTimeString)
        }
        
        return StatusData(
            isRunning: isRunning,
            pid: pid,
            configPath: configPath,
            startTime: startTime,
            uptimeSeconds: uptimeSeconds,
            lastExitCode: lastExitCode,
            errorReason: errorReason
        )
    }
    
    /// Decode data as VersionData
    func asVersionData() -> VersionData? {
        guard let data = data else { return nil }
        guard let dict = data.value as? [String: Any] else { return nil }
        
        guard let version = dict["version"] as? String else { return nil }
        let buildDate = dict["build_date"] as? String
        
        return VersionData(version: version, buildDate: buildDate)
    }
    
    /// Decode data as LogsData
    func asLogsData() -> LogsData? {
        guard let data = data else { return nil }
        guard let dict = data.value as? [String: Any] else { return nil }
        
        guard let lines = dict["lines"] as? [String] else { return nil }
        let totalLines = dict["total_lines"] as? Int ?? lines.count
        
        return LogsData(lines: lines, totalLines: totalLines)
    }
    
    /// Decode data as StartData
    func asStartData() -> StartData? {
        guard let data = data else { return nil }
        guard let dict = data.value as? [String: Any] else { return nil }
        
        guard let pid = dict["pid"] as? Int else { return nil }
        
        return StartData(pid: Int32(pid))
    }
}

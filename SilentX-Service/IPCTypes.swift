//
//  IPCTypes.swift
//  SilentX-Service
//
//  Shared IPC types - copied from main app for standalone service binary
//  Keep in sync with SilentX/Shared/IPCTypes.swift
//

import Foundation

// MARK: - IPCCommand

/// Commands supported by the IPC protocol
enum IPCCommand: String, Codable, CaseIterable {
    case version
    case start
    case stop
    case status
    case logs
    case ping
}

// MARK: - IPCRequest

/// Request message sent from main app to service over Unix socket
struct IPCRequest: Codable {
    let cmd: IPCCommand
    var configPath: String?
    var corePath: String?
    var authToken: String?
    var systemProxy: SystemProxySettings?
    
    enum CodingKeys: String, CodingKey {
        case cmd
        case configPath = "config_path"
        case corePath = "core_path"
        case authToken = "auth_token"
        case systemProxy = "system_proxy"
    }
}

// MARK: - SystemProxySettings

struct SystemProxySettings: Codable, Equatable {
    let enabled: Bool
    let host: String
    let port: Int
    let bypassDomains: [String]?
}

// MARK: - IPCResponse

/// Response message sent from service to main app
struct IPCResponse: Codable {
    let code: Int
    let message: String
    let data: AnyCodableData?
    
    var isSuccess: Bool { code == 0 }
    
    static func success(message: String = "OK", data: AnyCodableData? = nil) -> IPCResponse {
        IPCResponse(code: 0, message: message, data: data)
    }
    
    static func error(_ code: IPCErrorCode, message: String) -> IPCResponse {
        IPCResponse(code: code.rawValue, message: message, data: nil)
    }
}

// MARK: - AnyCodableData

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
    case success = 0
    case unknownError = 1
    case invalidCommand = 2
    case invalidParams = 3
    case coreAlreadyRunning = 4
    case coreNotRunning = 5
    case coreStartFailed = 6
    case configNotFound = 7
    case coreNotFound = 8
    case permissionDenied = 9
}

// MARK: - StatusData

/// Status data returned by the `status` command
struct StatusData: Codable {
    let isRunning: Bool
    let pid: Int32?
    let configPath: String?
    let startTime: Date?
    let uptimeSeconds: Int?
    let lastExitCode: Int32?
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
    
    static func running(pid: Int32, configPath: String, startTime: Date) -> StatusData {
        let uptime = Int(Date().timeIntervalSince(startTime))
        return StatusData(isRunning: true, pid: pid, configPath: configPath, startTime: startTime, uptimeSeconds: uptime, lastExitCode: nil, errorReason: nil)
    }
    
    static func stopped() -> StatusData {
        StatusData(isRunning: false, pid: nil, configPath: nil, startTime: nil, uptimeSeconds: nil, lastExitCode: nil, errorReason: nil)
    }
    
    static func crashed(exitCode: Int32, reason: String?) -> StatusData {
        StatusData(isRunning: false, pid: nil, configPath: nil, startTime: nil, uptimeSeconds: nil, lastExitCode: exitCode, errorReason: reason)
    }
}

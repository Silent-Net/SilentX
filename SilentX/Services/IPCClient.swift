//
//  IPCClient.swift
//  SilentX
//
//  Unix socket client for IPC communication with the privileged helper service
//

import Foundation
import Network
import os.log

// MARK: - IPCClient

/// Client for communicating with the SilentX privileged helper service
/// Uses Unix domain socket for IPC
final class IPCClient: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "IPCClient")
    private let socketPath: String
    private let timeout: TimeInterval
    
    // MARK: - Initialization
    
    nonisolated init(socketPath: String = "/tmp/silentx/silentx-service.sock", timeout: TimeInterval = 30.0) {
        self.socketPath = socketPath
        self.timeout = timeout
    }
    
    // MARK: - Public API
    
    /// Check if service is responsive
    func ping() async throws -> Bool {
        let response = try await send(.ping())
        return response.isSuccess
    }
    
    /// Get service version
    func version() async throws -> VersionData {
        let response = try await send(.version())
        
        guard response.isSuccess else {
            throw IPCClientError.serverError(code: response.code, message: response.message)
        }
        
        guard let versionData = response.asVersionData() else {
            throw IPCClientError.invalidResponse("Failed to parse version data")
        }
        
        return versionData
    }
    
    /// Start sing-box with configuration
    func start(configPath: String, corePath: String, systemProxy: SystemProxySettings? = nil) async throws -> Int32 {
        let request = IPCRequest.start(configPath: configPath, corePath: corePath, systemProxy: systemProxy)
        let response = try await send(request)
        
        guard response.isSuccess else {
            throw IPCClientError.serverError(code: response.code, message: response.message)
        }
        
        guard let startData = response.asStartData() else {
            // PID not required in response, return 0 if not present
            return 0
        }
        
        return startData.pid
    }
    
    /// Stop sing-box
    func stop() async throws {
        let response = try await send(.stop())
        
        // Accept both success and "not running" as valid
        if response.code == IPCErrorCode.coreNotRunning.rawValue {
            return // Already stopped, that's fine
        }
        
        guard response.isSuccess else {
            throw IPCClientError.serverError(code: response.code, message: response.message)
        }
    }
    
    /// Get current status
    func status() async throws -> StatusData {
        let response = try await send(.status())
        
        guard response.isSuccess else {
            throw IPCClientError.serverError(code: response.code, message: response.message)
        }
        
        guard let statusData = response.asStatusData() else {
            throw IPCClientError.invalidResponse("Failed to parse status data")
        }
        
        return statusData
    }
    
    /// Get recent logs
    func logs() async throws -> LogsData {
        let response = try await send(.logs())
        
        guard response.isSuccess else {
            throw IPCClientError.serverError(code: response.code, message: response.message)
        }
        
        guard let logsData = response.asLogsData() else {
            throw IPCClientError.invalidResponse("Failed to parse logs data")
        }
        
        return logsData
    }
    
    // MARK: - Core Send Method
    
    /// Send a request and receive response
    func send(_ request: IPCRequest) async throws -> IPCResponse {
        // Debug logging disabled for cleaner output
        
        // Encode request
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        guard var requestString = String(data: requestData, encoding: .utf8) else {
            throw IPCClientError.encodingFailed
        }
        requestString += "\n" // Protocol requires newline terminator
        
        // Connect and send using BSD sockets (NWConnection doesn't support AF_UNIX paths directly)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let response = try self.sendSync(requestString)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Synchronous Socket Operations
    
    private func sendSync(_ request: String) throws -> IPCResponse {
        // Create socket
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw IPCClientError.connectionFailed("Failed to create socket: errno=\(errno)")
        }
        defer { close(sock) }
        
        // Set timeouts
        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = 0
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        // Setup address
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let rawPtr = UnsafeMutableRawPointer(ptr)
            _ = pathBytes.withUnsafeBytes { bytes in
                memcpy(rawPtr, bytes.baseAddress!, min(bytes.count, 104))
            }
        }
        
        // Connect
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard connectResult == 0 else {
            let errorMessage: String
            switch errno {
            case ENOENT:
                errorMessage = "Service not running (socket not found)"
            case ECONNREFUSED:
                errorMessage = "Connection refused (service may not be running)"
            case EACCES:
                errorMessage = "Permission denied"
            default:
                errorMessage = "Connection failed: errno=\(errno)"
            }
            throw IPCClientError.connectionFailed(errorMessage)
        }
        
        // Send request
        let requestBytes = Array(request.utf8)
        let bytesSent = requestBytes.withUnsafeBytes { ptr in
            Darwin.send(sock, ptr.baseAddress!, ptr.count, 0)
        }
        
        guard bytesSent == requestBytes.count else {
            throw IPCClientError.sendFailed("Failed to send request: only \(bytesSent)/\(requestBytes.count) bytes sent")
        }
        
        // Receive response
        var buffer = [CChar](repeating: 0, count: 65536)
        var response = ""
        
        while true {
            let bytesRead = recv(sock, &buffer, buffer.count - 1, 0)
            
            if bytesRead < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw IPCClientError.timeout
                }
                throw IPCClientError.receiveFailed("Failed to receive response: errno=\(errno)")
            }
            
            if bytesRead == 0 {
                break // Connection closed
            }
            
            buffer[bytesRead] = 0
            response += String(cString: buffer)
            
            // Check for newline (end of message)
            if response.contains("\n") {
                break
            }
        }
        
        response = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !response.isEmpty else {
            throw IPCClientError.emptyResponse
        }
        
        // Parse response
        guard let responseData = response.data(using: .utf8) else {
            throw IPCClientError.invalidResponse("Response is not valid UTF-8")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let ipcResponse = try decoder.decode(IPCResponse.self, from: responseData)
            // Debug logging disabled for cleaner output
            return ipcResponse
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription)")
            throw IPCClientError.invalidResponse("Failed to parse response JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Service Status Check
    
    /// Check if the service is available (socket exists and responds)
    static func isServiceAvailable(socketPath: String = "/tmp/silentx/silentx-service.sock") async -> Bool {
        // First check if socket file exists
        guard FileManager.default.fileExists(atPath: socketPath) else {
            return false
        }
        
        // Try to ping
        let client = IPCClient(socketPath: socketPath, timeout: 2.0)
        do {
            return try await client.ping()
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum IPCClientError: LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case timeout
    case emptyResponse
    case invalidResponse(String)
    case encodingFailed
    case serverError(code: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Failed to connect to service: \(reason)"
        case .sendFailed(let reason):
            return "Failed to send request: \(reason)"
        case .receiveFailed(let reason):
            return "Failed to receive response: \(reason)"
        case .timeout:
            return "Request timed out"
        case .emptyResponse:
            return "Received empty response from service"
        case .invalidResponse(let reason):
            return "Invalid response from service: \(reason)"
        case .encodingFailed:
            return "Failed to encode request"
        case .serverError(let code, let message):
            return "Service error (\(code)): \(message)"
        }
    }
    
    /// Check if this error indicates the service is not running
    var isServiceUnavailable: Bool {
        switch self {
        case .connectionFailed:
            return true
        default:
            return false
        }
    }
}

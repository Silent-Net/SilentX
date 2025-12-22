//
//  IPCServer.swift
//  SilentX-Service
//
//  Unix socket server for IPC communication with the main app
//

import Foundation
import os.log

// MARK: - IPCServer

/// Unix socket server that handles IPC requests from the main app
final class IPCServer {
    
    // MARK: - Properties
    
    private let coreManager: CoreManager
    private let logger = Logger(subsystem: "com.silentnet.silentx.service", category: "IPCServer")
    private let socketPath = "/tmp/silentx/silentx-service.sock"
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private var acceptQueue: DispatchQueue
    
    // MARK: - Initialization
    
    init(coreManager: CoreManager) {
        self.coreManager = coreManager
        self.acceptQueue = DispatchQueue(label: "com.silentnet.silentx.service.accept", qos: .userInitiated)
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the IPC server
    func start() throws {
        guard !isRunning else {
            logger.warning("Server already running")
            return
        }
        
        // Remove existing socket file
        unlink(socketPath)
        
        // Create Unix domain socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw IPCServerError.socketCreationFailed(errno: errno)
        }
        
        // Allow socket reuse
        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind to socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let rawPtr = UnsafeMutableRawPointer(ptr)
            _ = pathBytes.withUnsafeBytes { bytes in
                memcpy(rawPtr, bytes.baseAddress!, min(bytes.count, 104))
            }
        }
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard bindResult == 0 else {
            close(serverSocket)
            throw IPCServerError.bindFailed(errno: errno, path: socketPath)
        }
        
        // Set socket permissions to 0777 so unprivileged apps can connect
        chmod(socketPath, 0o777)
        
        // Start listening
        guard listen(serverSocket, 5) == 0 else {
            close(serverSocket)
            unlink(socketPath)
            throw IPCServerError.listenFailed(errno: errno)
        }
        
        isRunning = true
        logger.info("IPC server listening on \(self.socketPath)")
        
        // Start accept loop
        startAcceptLoop()
    }
    
    /// Stop the IPC server
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        
        unlink(socketPath)
        logger.info("IPC server stopped")
    }
    
    // MARK: - Accept Loop
    
    private func startAcceptLoop() {
        acceptQueue.async { [weak self] in
            guard let self = self else { return }
            
            while self.isRunning {
                var clientAddr = sockaddr_un()
                var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
                
                let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        accept(self.serverSocket, sockaddrPtr, &addrLen)
                    }
                }
                
                guard clientSocket >= 0 else {
                    if self.isRunning {
                        self.logger.error("Accept failed: \(errno)")
                    }
                    continue
                }
                
                // Handle client in background
                DispatchQueue.global(qos: .userInitiated).async {
                    self.handleClient(socket: clientSocket)
                }
            }
        }
    }
    
    // MARK: - Client Handling
    
    private func handleClient(socket clientSocket: Int32) {
        defer { close(clientSocket) }
        
        // Read request (line-based JSON protocol)
        guard let requestLine = readLine(from: clientSocket) else {
            logger.warning("Failed to read request from client")
            return
        }
        
        logger.debug("Received request: \(requestLine)")
        
        // Parse request
        guard let requestData = requestLine.data(using: .utf8),
              let request = try? JSONDecoder().decode(IPCRequest.self, from: requestData) else {
            let response = IPCResponse.error(.invalidCommand, message: "Failed to parse request JSON")
            writeResponse(response, to: clientSocket)
            return
        }
        
        // Process request
        let response = processRequest(request)
        
        // Write response
        writeResponse(response, to: clientSocket)
    }
    
    /// Read a line from socket (until newline or EOF)
    private func readLine(from socket: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 65536) // 64KB buffer
        var line = ""
        
        // Set read timeout (30 seconds)
        var tv = timeval()
        tv.tv_sec = 30
        tv.tv_usec = 0
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        while true {
            let bytesRead = recv(socket, &buffer, buffer.count - 1, 0)
            
            if bytesRead <= 0 {
                // EOF or error
                return line.isEmpty ? nil : line
            }
            
            buffer[bytesRead] = 0
            let chunk = String(cString: buffer)
            line += chunk
            
            // Check for newline (end of message)
            if line.contains("\n") {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    /// Write response to socket
    private func writeResponse(_ response: IPCResponse, to socket: Int32) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            
            guard var jsonString = String(data: data, encoding: .utf8) else {
                logger.error("Failed to encode response as string")
                return
            }
            
            jsonString += "\n"
            
            let bytes = Array(jsonString.utf8)
            _ = bytes.withUnsafeBytes { ptr in
                send(socket, ptr.baseAddress!, ptr.count, 0)
            }
            
            logger.debug("Sent response: code=\(response.code), message=\(response.message)")
            
        } catch {
            logger.error("Failed to encode response: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Request Processing
    
    private func processRequest(_ request: IPCRequest) -> IPCResponse {
        switch request.cmd {
        case .ping:
            return IPCResponse.success(message: "pong")
            
        case .version:
            let versionData: [String: Any] = [
                "version": serviceVersion,
                "build_date": serviceBuildDate
            ]
            return IPCResponse.success(message: "OK", data: AnyCodableData(versionData))
            
        case .start:
            return handleStart(request)
            
        case .stop:
            return handleStop()
            
        case .status:
            return handleStatus()
            
        case .logs:
            return handleLogs()
        }
    }
    
    private func handleStart(_ request: IPCRequest) -> IPCResponse {
        guard let configPath = request.configPath else {
            return IPCResponse.error(.invalidParams, message: "Missing config_path parameter")
        }
        
        guard let corePath = request.corePath else {
            return IPCResponse.error(.invalidParams, message: "Missing core_path parameter")
        }
        
        // T119: Config switching - allow start even if already running
        // CoreManager.startCore() will handle stopping the old process first
        // This enables seamless profile switching without requiring explicit stop
        
        // Validate paths
        guard FileManager.default.fileExists(atPath: configPath) else {
            return IPCResponse.error(.configNotFound, message: "Config file not found: \(configPath)")
        }
        
        guard FileManager.default.fileExists(atPath: corePath) else {
            return IPCResponse.error(.coreNotFound, message: "Core binary not found: \(corePath)")
        }
        
        guard FileManager.default.isExecutableFile(atPath: corePath) else {
            return IPCResponse.error(.coreNotFound, message: "Core binary is not executable: \(corePath)")
        }
        
        // Start core (synchronously for simplicity)
        let semaphore = DispatchSemaphore(value: 0)
        var startResult: Result<Int32, Error>?
        
        Task {
            do {
                let pid = try await coreManager.startCore(
                    configPath: configPath,
                    corePath: corePath,
                    systemProxy: request.systemProxy
                )
                startResult = .success(pid)
            } catch {
                startResult = .failure(error)
            }
            semaphore.signal()
        }
        
        // Wait for start (max 30 seconds)
        let timeout = DispatchTime.now() + .seconds(30)
        if semaphore.wait(timeout: timeout) == .timedOut {
            return IPCResponse.error(.coreStartFailed, message: "Start operation timed out")
        }
        
        switch startResult {
        case .success(let pid):
            let data: [String: Any] = ["pid": Int(pid)]
            return IPCResponse.success(message: "Core started successfully", data: AnyCodableData(data))
        case .failure(let error):
            return IPCResponse.error(.coreStartFailed, message: "Failed to start core: \(error.localizedDescription)")
        case .none:
            return IPCResponse.error(.unknownError, message: "Unknown error during start")
        }
    }
    
    private func handleStop() -> IPCResponse {
        // Check running state via async status
        let statusSemaphore = DispatchSemaphore(value: 0)
        var statusData: StatusData?
        Task {
            statusData = await coreManager.getStatusAsync()
            statusSemaphore.signal()
        }
        _ = statusSemaphore.wait(timeout: .now() + 2)
        if statusData?.isRunning != true {
            return IPCResponse.error(.coreNotRunning, message: "Core not running")
        }
        
        // Stop core (synchronously)
        let semaphore = DispatchSemaphore(value: 0)
        var stopError: Error?
        
        Task {
            do {
                try await coreManager.stopCore()
            } catch {
                stopError = error
            }
            semaphore.signal()
        }
        
        // Wait for stop (max 10 seconds)
        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            return IPCResponse.error(.unknownError, message: "Stop operation timed out")
        }
        
        if let error = stopError {
            return IPCResponse.error(.unknownError, message: "Failed to stop core: \(error.localizedDescription)")
        }
        
        return IPCResponse.success(message: "Core stopped successfully")
    }
    
    private func handleStatus() -> IPCResponse {
        // Get status asynchronously
        let semaphore = DispatchSemaphore(value: 0)
        var statusData: StatusData?
        
        Task {
            statusData = await coreManager.getStatusAsync()
            semaphore.signal()
        }
        
        // Wait for async operation (max 5s)
        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            return IPCResponse.error(.unknownError, message: "Status request timed out")
        }
        
        guard let status = statusData else {
            return IPCResponse.error(.unknownError, message: "Failed to get status")
        }
        
        var data: [String: Any] = [
            "is_running": status.isRunning
        ]
        
        if status.isRunning {
            data["pid"] = status.pid.map { Int($0) }
            data["config_path"] = status.configPath
            data["uptime_seconds"] = status.uptimeSeconds
            
            if let startTime = status.startTime {
                let formatter = ISO8601DateFormatter()
                data["start_time"] = formatter.string(from: startTime)
            }
        }
        
        return IPCResponse.success(message: "OK", data: AnyCodableData(data))
    }
    
    private func handleLogs() -> IPCResponse {
        // Get logs asynchronously
        let semaphore = DispatchSemaphore(value: 0)
        var logs: [String]?
        
        Task {
            logs = await coreManager.getRecentLogsAsync()
            semaphore.signal()
        }
        
        // Wait for async operation (max 5s)
        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            return IPCResponse.error(.unknownError, message: "Logs request timed out")
        }
        
        guard let logLines = logs else {
            return IPCResponse.error(.unknownError, message: "Failed to get logs")
        }
        
        let data: [String: Any] = [
            "lines": logLines,
            "total_lines": logLines.count
        ]
        
        return IPCResponse.success(message: "OK", data: AnyCodableData(data))
    }
}

// MARK: - Errors

enum IPCServerError: LocalizedError {
    case socketCreationFailed(errno: Int32)
    case bindFailed(errno: Int32, path: String)
    case listenFailed(errno: Int32)
    
    var errorDescription: String? {
        switch self {
        case .socketCreationFailed(let errno):
            return "Failed to create socket: errno=\(errno)"
        case .bindFailed(let errno, let path):
            return "Failed to bind to \(path): errno=\(errno)"
        case .listenFailed(let errno):
            return "Failed to listen: errno=\(errno)"
        }
    }
}

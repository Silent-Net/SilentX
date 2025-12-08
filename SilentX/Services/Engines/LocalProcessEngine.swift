import Combine
import Darwin
import Foundation
import SwiftData
import OSLog

/// Local process-based proxy engine
/// Launches sing-box directly as a subprocess with improved error handling
@MainActor
final class LocalProcessEngine: ProxyEngine {

    // MARK: - Private Properties (Logging)

    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "LocalProcessEngine")

    // MARK: - ProxyEngine Protocol

    private let statusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)

    var status: ConnectionStatus {
        statusSubject.value
    }

    var statusPublisher: AnyPublisher<ConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    let engineType: EngineType = .localProcess

    // MARK: - Private Properties

    private var coreProcess: Process?
    private var coreProcessPid: pid_t?
    private var monitorTask: Task<Void, Never>?
    private var configFileURL: URL?
    private var privilegedLogFile: URL?
    private var activeTunInterfaces: [String] = []
    private let privilegedPidFile = URL(fileURLWithPath: "/tmp/singbox-privileged.pid")
    private let privilegedDiagFile = URL(fileURLWithPath: "/tmp/singbox-diag.log")
    private let configurationService: any ConfigurationServiceProtocol
    private let coreVersionService: any CoreVersionServiceProtocol

    // MARK: - Initialization

    init(
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        coreVersionService: (any CoreVersionServiceProtocol)? = nil
    ) {
        self.configurationService = configurationService ?? ConfigurationService()
        self.coreVersionService = coreVersionService ?? {
            let context = ModelContext(SilentXApp.sharedModelContainer)
            return CoreVersionService(modelContext: context)
        }()
    }

    // MARK: - ProxyEngine Implementation

    func start(config: ProxyConfiguration) async throws {
        guard status == .disconnected else {
            throw ProxyError.unknown("Cannot start - already \(status)")
        }

        logger.info("Starting LocalProcessEngine with config: \(config.configPath.lastPathComponent)")
        statusSubject.send(.connecting)

        do {
            // 1. Validate configuration file exists and is accessible
            try config.validate()
            logger.debug("Configuration validated successfully")

            // 2. Parse and validate sing-box config content
            let configContent = try String(contentsOf: config.configPath, encoding: .utf8)
            let validation = configurationService.validate(json: configContent)
            guard validation.isValid else {
                logger.error("Configuration validation failed: \(validation.errors.first?.message ?? "Unknown error")")
                throw ProxyError.configInvalid(validation.errors.first?.message ?? "Invalid configuration")
            }

            // 3. Extract listen ports and any tun interfaces; preflight cleanup
            let ports = try extractPorts(from: configContent)
            let tunInterfaces = try extractTunInterfaces(from: configContent)
            logger.debug("Extracted ports: \(ports) tunInterfaces: \(tunInterfaces)")
            activeTunInterfaces = tunInterfaces
            cleanupStaleCacheDB(configPath: config.configPath)
            // Note: Stale process cleanup now handled inside privileged script

            // 4. Prepare sing-box binary for execution
            logger.debug("Preparing core binary at: \(config.corePath.path)")
            try await prepareCoreBinary(at: config.corePath)

            // 5. Launch sing-box process with sudo prompt (Authorization dialog via AppleScript)
            logger.info("Launching sing-box process with administrator privileges…")
            let launch = try launchPrivilegedProcess(
                corePath: config.corePath,
                configPath: config.configPath,
                tunInterfaces: tunInterfaces
            )
            coreProcessPid = launch.pid
            coreProcess = nil // privileged launch is not tracked by Process
            configFileURL = config.configPath
            privilegedLogFile = launch.logFile
            startPrivilegedMonitor(pid: launch.pid, logFile: launch.logFile)

            // 6. Wait for core to be ready (check port availability)
            logger.debug("Waiting for core to be ready (timeout: 30s)...")
            try await waitForCoreReady(ports: ports, timeout: 30.0)

            // 7. Update status to connected
            let info = ConnectionInfo(
                engineType: engineType,
                startTime: Date(),
                configName: config.configPath.lastPathComponent,
                listenPorts: ports
            )
            statusSubject.send(.connected(info))
            logger.info("Successfully started proxy on ports: \(ports)")

        } catch let error as ProxyError {
            logger.error("Failed to start: \(error.localizedDescription)")
            statusSubject.send(.error(error))
            cleanup()
            throw error
        } catch {
            logger.error("Failed to start: \(error.localizedDescription)")
            let proxyError = ProxyError.unknown(error.localizedDescription)
            statusSubject.send(.error(proxyError))
            cleanup()
            throw proxyError
        }
    }

    func stop() async throws {
        switch status {
        case .connected, .connecting:
            break
        default:
            throw ProxyError.unknown("Cannot stop - not connected")
        }

        logger.info("Stopping LocalProcessEngine...")
        statusSubject.send(.disconnecting)

        do {
            // Graceful shutdown: SIGTERM → wait → SIGKILL if needed
            if let process = coreProcess, process.isRunning {
                logger.debug("Sending SIGTERM to process…")
                process.terminate() // SIGTERM

                // Wait up to 3 seconds for graceful shutdown
                let deadline = Date().addingTimeInterval(3.0)
                while process.isRunning && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                }

                // Force kill if still running
                if process.isRunning {
                    logger.warning("Process didn't terminate gracefully, sending SIGKILL…")
                    kill(process.processIdentifier, SIGKILL)
                } else {
                    logger.debug("Process terminated gracefully")
                }
            } else if let pid = coreProcessPid {
                logger.debug("Stopping privileged process pid=\(pid) with admin rights…")
                try stopPrivilegedProcess(pid: pid)
            }

            cleanup()
            statusSubject.send(.disconnected)
            logger.info("Stopped successfully")
        } catch {
            // Surface failure to UI instead of leaving it stuck
            let proxyError = ProxyError.coreStartFailed(error.localizedDescription)
            statusSubject.send(.error(proxyError))
            cleanup()
            throw proxyError
        }
    }

    func validate(config: ProxyConfiguration) async -> [ProxyError] {
        var errors: [ProxyError] = []

        // Check config file exists
        if !FileManager.default.fileExists(atPath: config.configPath.path) {
            errors.append(.configNotFound)
        }

        // Check core binary exists
        if !FileManager.default.fileExists(atPath: config.corePath.path) {
            errors.append(.coreNotFound)
        }

        // Check core is executable
        if !FileManager.default.isExecutableFile(atPath: config.corePath.path) {
            errors.append(.coreStartFailed("Core file is not executable"))
        }

        // Validate config JSON format
        if errors.isEmpty {
            do {
                let configContent = try String(contentsOf: config.configPath, encoding: .utf8)
                let validation = configurationService.validate(json: configContent)
                if !validation.isValid {
                    errors.append(.configInvalid(validation.errors.first?.message ?? "Invalid JSON"))
                }
            } catch {
                errors.append(.configInvalid("Cannot read configuration file"))
            }
        }

        return errors
    }

    // MARK: - Private Helper Methods

    private func extractPorts(from configJSON: String) throws -> [Int] {
        guard let data = configJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return []
        }

        var ports: [Int] = []
        for inbound in inbounds {
            if let listenPort = inbound["listen_port"] as? Int {
                ports.append(listenPort)
            }
        }
        return ports
    }

    private func extractTunInterfaces(from configJSON: String) throws -> [String] {
        guard let data = configJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return []
        }

        var names: [String] = []
        for inbound in inbounds {
            guard let type = inbound["type"] as? String, type == "tun" else { continue }
            if let name = inbound["interface_name"] as? String, let sanitized = sanitizeInterfaceName(name) {
                names.append(sanitized)
            }
        }
        return names
    }

    private func isInterfacePresent(_ name: String) -> Bool {
        name.withCString { if_nametoindex($0) } != 0
    }

    private func checkPortsAvailable(_ ports: [Int]) async throws {
        var conflictingPorts: [Int] = []

        for port in ports {
            if isPortInUse(port) {
                conflictingPorts.append(port)
            }
        }

        if !conflictingPorts.isEmpty {
            throw ProxyError.portConflict(conflictingPorts)
        }
    }

    private func isPortInUse(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult != 0 // Port in use if bind fails
    }

    private func prepareCoreBinary(at corePath: URL) async throws {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Remove quarantine attribute
                let xattrProcess = Process()
                xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProcess.arguments = ["-d", "com.apple.quarantine", corePath.path]
                xattrProcess.standardOutput = FileHandle.nullDevice
                xattrProcess.standardError = FileHandle.nullDevice
                try? xattrProcess.run()
                xattrProcess.waitUntilExit()

                // Ensure execute permission
                let chmodProcess = Process()
                chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmodProcess.arguments = ["+x", corePath.path]
                chmodProcess.standardOutput = FileHandle.nullDevice
                chmodProcess.standardError = FileHandle.nullDevice
                try? chmodProcess.run()
                chmodProcess.waitUntilExit()

                continuation.resume()
            }
        }
    }

    private func launchPrivilegedProcess(corePath: URL, configPath: URL, tunInterfaces: [String]) throws -> (pid: pid_t, logFile: URL) {
        let logFile = URL(fileURLWithPath: "/tmp/singbox-privileged.log")
        let pidFile = privilegedPidFile
        let diagFile = privilegedDiagFile
        try? FileManager.default.removeItem(at: logFile)
        try? FileManager.default.removeItem(at: pidFile)
        try? FileManager.default.removeItem(at: diagFile)

        func shellEscape(_ path: String) -> String {
            "'" + path.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
        }

        let coreArg = shellEscape(corePath.path)
        let configArg = shellEscape(configPath.path)
        let logArg = shellEscape(logFile.path)
        let diagArg = shellEscape(diagFile.path)
        let workdirArg = shellEscape(configPath.deletingLastPathComponent().path)
        let pidArg = shellEscape(pidFile.path)

        // TUN cleanup is now handled by killing sing-box processes
        let tunCleanup = ""

        // Enhanced diagnostic script with cleanup embedded
        let launchScriptURL = URL(fileURLWithPath: "/tmp/singbox-launch.sh")
        let scriptContents = """
        #!/bin/sh
        # Clean up log files first (must be done with root privilege since they're root-owned)
        rm -f \(logArg) \(pidArg) \(diagArg)
        exec > \(diagArg) 2>&1
        set -x
        echo "=== Sing-Box Diagnostic ==="
        echo "Date: $(date)"
        echo "Binary: \(coreArg)"
        echo "Config: \(configArg)"
        echo ""
        
        # Binary checks
        if [ ! -f \(coreArg) ]; then echo "ERROR: Binary not found"; exit 1; fi
        if [ ! -x \(coreArg) ]; then echo "ERROR: Binary not executable"; exit 1; fi
        file \(coreArg)
        ls -la \(coreArg)
        echo ""
        
        # Version check
        echo "=== Version ==="
        \(coreArg) version || echo "Version failed: $?"
        echo ""
        
        # Config check
        echo "=== Config Check ==="
        \(coreArg) check -c \(configArg) || echo "Config check failed: $?"
        echo ""
        
        # Kill stale sing-box processes (this runs with sudo privilege)
        echo "=== Cleanup Stale Processes ==="
        killall -TERM sing-box 2>/dev/null || true
        sleep 0.5
        killall -KILL sing-box 2>/dev/null || true
        sleep 0.5
        echo "Cleanup complete"
        echo ""
        
        cd \(workdirArg) || { echo "ERROR: Cannot cd"; exit 1; }
        \(tunCleanup)
        echo "=== Launching ==="
        ( \(coreArg) run -c \(configArg) </dev/null >> \(logArg) 2>&1 & pid=$!; echo $pid > \(pidArg); echo "PID: $pid"; echo $pid )
        """
        try scriptContents.write(to: launchScriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launchScriptURL.path)

        let command = "sh \(shellEscape(launchScriptURL.path))"
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ProxyError.coreStartFailed("Failed to prompt for password: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let diagOutput = (try? String(contentsOf: diagFile, encoding: .utf8)) ?? ""
        if !diagOutput.isEmpty {
            logger.debug("Diagnostic log:\n\(diagOutput)")
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8), !errorString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProxyError.coreStartFailed("Authorization failed: \(errorString)\n\nDiagnostic:\n\(diagOutput)")
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let rawOutput = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        logger.debug("Privileged launch raw output: \(rawOutput)")

        let pidFromFile = (try? String(contentsOf: pidFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pidToken = (pidFromFile?.isEmpty == false ? pidFromFile : nil) ?? rawOutput.split(whereSeparator: { !$0.isNumber }).first.map(String.init)

        guard let pidString = pidToken, let pid = pid_t(pidString) else {
            let logTail = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
            let detail = "stdout: \(rawOutput)\nlog: \(logTail)\ndiagnostic: \(diagOutput)"
            throw ProxyError.coreStartFailed("Unable to parse PID\n\(detail)")
        }

        return (pid, logFile)
    }

    private func sanitizeInterfaceName(_ name: String) -> String? {
        // Accept only alphanumerics, dash, underscore to avoid shell injection
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        if name.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return name
        }
        return nil
    }

    private func waitForCoreReady(ports: [Int], timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        // If no ports to check (TUN-only mode), wait for "sing-box started" in log
        if ports.isEmpty {
            let startTime = Date()
            let tunDeadline = startTime.addingTimeInterval(timeout)
            
            logger.debug("TUN-only mode: waiting for 'sing-box started' in log (timeout: \(timeout)s)")
            
            while Date() < tunDeadline {
                let processRunning = isPrivilegedProcessRunning
                logger.debug("Loop iteration: process running = \(processRunning)")
                
                if !processRunning {
                    let detail = logTail()
                    logger.error("Process not running, failing with detail length: \(detail.count)")
                    throw ProxyError.coreStartFailed(detail.isEmpty ? "Core process exited during startup" : detail)
                }

                // Interface presence is a stronger signal than log content
                if let upName = activeTunInterfaces.first(where: { isInterfacePresent($0) }) {
                    logger.info("TUN interface \(upName) is up; considering core ready")
                    return
                }
                
                // Check if sing-box reported successful start
                // Force re-read file on each iteration to avoid caching issues
                if let logFile = privilegedLogFile {
                    do {
                        // Use FileHandle to force fresh read from disk
                        let handle = try FileHandle(forReadingFrom: logFile)
                        defer { try? handle.close() }
                        let data = handle.readDataToEndOfFile()
                        if let logContent = String(data: data, encoding: .utf8) {
                            logger.debug("Read \(data.count) bytes from log, contains 'sing-box started': \(logContent.contains("sing-box started"))")
                            if logContent.contains("sing-box started") {
                                logger.info("TUN mode started successfully")
                                return
                            }
                        }
                    } catch {
                        // Log file may not exist yet or permission issue, continue waiting
                        logger.debug("Log read error (will retry): \(error.localizedDescription)")
                    }
                }
                
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1s (increased from 0.5s to reduce disk I/O)
            }
            
            // Fallback: if process still running and log has data, accept after timeout/slow start
            if isPrivilegedProcessRunning {
                logger.warning("TUN startup timeout but process still running with log present, assuming success")
                return
            }

            throw ProxyError.timeout
        }

        while Date() < deadline {
            // Check if process is still running
            if !isPrivilegedProcessRunning {
                let detail = logTail()
                throw ProxyError.coreStartFailed(detail.isEmpty ? "Core process exited during startup" : detail)
            }

            // Check all ports are listening
            var allReady = true
            for port in ports {
                if !isPortListening(port) {
                    allReady = false
                    break
                }
            }

            if allReady {
                return
            }

            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        // Timeout - check if process is still running (may still be initializing)
        if isPrivilegedProcessRunning {
            return // Consider ready if still running
        }

        let detail = logTail()
        if detail.isEmpty {
            throw ProxyError.timeout
        } else {
            throw ProxyError.coreStartFailed(detail)
        }
    }

    private func cleanupStaleResources(tunInterfaces: [String], ports: [Int]) async throws {
        // Kill ALL sing-box processes (root and non-root) to release TUN interfaces
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        killProcess.arguments = ["killall", "-TERM", "sing-box"]
        killProcess.standardOutput = FileHandle.nullDevice
        killProcess.standardError = FileHandle.nullDevice
        try? killProcess.run()
        killProcess.waitUntilExit()
        
        // Wait for processes to die and TUN interfaces to disappear
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Force kill if still alive
        let forceKillProcess = Process()
        forceKillProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        forceKillProcess.arguments = ["killall", "-KILL", "sing-box"]
        forceKillProcess.standardOutput = FileHandle.nullDevice
        forceKillProcess.standardError = FileHandle.nullDevice
        try? forceKillProcess.run()
        forceKillProcess.waitUntilExit()
        
        // Wait for TUN interface to disappear
        let maxWait = Date().addingTimeInterval(3.0)
        for name in tunInterfaces {
            while Date() < maxWait {
                let checkProcess = Process()
                checkProcess.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
                checkProcess.arguments = [name]
                checkProcess.standardOutput = FileHandle.nullDevice
                checkProcess.standardError = FileHandle.nullDevice
                try? checkProcess.run()
                checkProcess.waitUntilExit()
                
                if checkProcess.terminationStatus != 0 {
                    // Interface gone
                    break
                }
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            }
        }
        
        // Clean up pid file
        let pidFile = URL(fileURLWithPath: "/tmp/singbox-privileged.pid")
        try? FileManager.default.removeItem(at: pidFile)
    }

    private func cleanupStaleCacheDB(configPath: URL) {
        // Remove stale cache.db from previous runs (root-owned) to prevent initialization timeout
        let cacheDB = configPath.deletingLastPathComponent().appendingPathComponent("cache.db")
        if FileManager.default.fileExists(atPath: cacheDB.path) {
            try? FileManager.default.removeItem(at: cacheDB)
            logger.debug("Removed stale cache.db at \(cacheDB.path)")
        }
    }

    private func stopPrivilegedProcess(pid: pid_t) throws {
        let stopScript = "kill -TERM \(pid) 2>/dev/null || true; sleep 0.5; kill -KILL \(pid) 2>/dev/null || true; killall -TERM sing-box 2>/dev/null || true; sleep 0.2; killall -KILL sing-box 2>/dev/null || true; rm -f \(privilegedPidFile.path) \(privilegedDiagFile.path) \(privilegedLogFile?.path ?? "/tmp/singbox-privileged.log")"

        // Fast path: try sudo without prompting (returns non-zero if credentials not cached)
        let sudoProcess = Process()
        sudoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        sudoProcess.arguments = ["-n", "/bin/sh", "-c", stopScript]
        sudoProcess.standardOutput = Pipe()
        sudoProcess.standardError = Pipe()
        try? sudoProcess.run()
        sudoProcess.waitUntilExit()
        if sudoProcess.terminationStatus == 0 {
            return
        }

        // Fallback: prompt once via AppleScript
        let stopScriptURL = URL(fileURLWithPath: "/tmp/singbox-stop.sh")
        try stopScript.write(to: stopScriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stopScriptURL.path)

        func shellEscape(_ path: String) -> String {
            "'" + path.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
        }

        let command = "sh \(shellEscape(stopScriptURL.path))"
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let osaScript = "do shell script \"\(escapedCommand)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", osaScript]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ProxyError.coreStartFailed("Failed to stop privileged process: \(error.localizedDescription)")
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8), !errorString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProxyError.coreStartFailed("Failed to stop privileged process: \(errorString)")
        }
    }

    private func isPortListening(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return connectResult == 0
    }

    private func cleanup() {
        monitorTask?.cancel()
        monitorTask = nil
        coreProcess?.terminate()
        coreProcess = nil
        coreProcessPid = nil
        configFileURL = nil
        privilegedLogFile = nil
        activeTunInterfaces = []
    }

    private var isPrivilegedProcessRunning: Bool {
        if let process = coreProcess {
            return process.isRunning
        }
        if let pid = coreProcessPid {
            // kill(pid, 0) returns 0 if process exists and we have permission
            // If it fails, check errno IMMEDIATELY before it gets overwritten
            let result = kill(pid, 0)
            if result == 0 {
                logger.debug("kill(\(pid), 0) returned 0 - process running")
                return true
            }
            // Capture errno immediately after kill() before any other syscall
            let errorCode = errno
            // EPERM (1) means process exists but we don't have permission (root process)
            // ESRCH (3) means process doesn't exist
            let isRunning = errorCode == EPERM
            logger.debug("kill(\(pid), 0) returned \(result), errno=\(errorCode) (EPERM=\(EPERM), ESRCH=\(ESRCH)) -> \(isRunning)")
            return isRunning
        }
        logger.debug("No process or PID - returning false")
        return false
    }

    private func logTail() -> String {
        let mainLog = privilegedLogFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let diagLog = (try? String(contentsOf: privilegedDiagFile, encoding: .utf8)) ?? ""
        
        if diagLog.isEmpty && mainLog.isEmpty { return "" }
        
        var result = ""
        if !diagLog.isEmpty {
            result += "=== Diagnostic ===\n\(diagLog)\n"
        }
        if !mainLog.isEmpty {
            result += "=== Runtime ===\n\(mainLog)"
        }
        return result
    }

    private func startPrivilegedMonitor(pid: pid_t, logFile: URL) {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                guard let self = self else { return }

                // Check if process is running (handle EPERM for root processes)
                let result = kill(pid, 0)
                let running = (result == 0) || (result == -1 && errno == EPERM)
                if running { continue }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    switch self.status {
                    case .connected:
                        let logTail = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
                        let detail = logTail.isEmpty ? "Privileged process exited" : "Privileged process exited\n\(logTail)"
                        self.statusSubject.send(.error(.coreStartFailed(detail)))
                    case .disconnecting, .disconnected:
                        break
                    default:
                        break
                    }
                    self.cleanup()
                }
                return
            }
        }
    }
}

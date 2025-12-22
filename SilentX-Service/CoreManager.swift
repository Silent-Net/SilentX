//
//  CoreManager.swift
//  SilentX-Service
//
//  Manages the sing-box process lifecycle
//

import Foundation
import os.log
import Darwin.POSIX.ifaddrs

// MARK: - CoreManager

/// Manages the sing-box process lifecycle including start, stop, and monitoring
actor CoreManager {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx.service", category: "CoreManager")
    
    private var process: Process?
    private var startTime: Date?
    private var configPath: String?
    private var logBuffer: [String] = []
    private let maxLogLines = 1000
    
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var appliedSystemProxySnapshot: [String: ProxySnapshot]?
    
    // T067: Crash detection state
    private var lastExitCode: Int32?
    private var crashReason: String?
    private var crashed: Bool = false
    
    // MARK: - Public Properties (nonisolated for sync access)
    
    nonisolated var isRunning: Bool {
        // Use underlying process state via unsafe assumption
        // In practice, this is accessed from IPC handler which will properly await
        return false // Will be properly implemented via getStatus()
    }
    
    nonisolated var currentPid: Int32? {
        return nil // Will be properly implemented via getStatus()
    }
    
    // MARK: - Core Lifecycle
    
    /// Start sing-box with the given configuration
    /// - Parameters:
    ///   - configPath: Path to sing-box configuration file
    ///   - corePath: Path to sing-box binary
    ///   - systemProxy: System proxy settings to apply (auto-detected from config if nil)
    /// - Returns: Process ID of started sing-box
    ///
    /// T119: If a different config is already running, stops it first (config switching).
    func startCore(configPath: String, corePath: String, systemProxy: SystemProxySettings? = nil) async throws -> Int32 {
        // === DIAGNOSTIC LOGGING START ===
        logger.info("========== START CORE DIAGNOSTIC ==========")
        logger.info("Config path: \(configPath)")
        logger.info("Core path: \(corePath)")
        logger.info("Config exists: \(FileManager.default.fileExists(atPath: configPath))")
        logger.info("Core exists: \(FileManager.default.fileExists(atPath: corePath))")
        
        let workingDir = URL(fileURLWithPath: configPath).deletingLastPathComponent().path
        logger.info("Working directory: \(workingDir)")
        
        // Log current utun interfaces BEFORE cleanup
        let utunsBefore = listAllUtunInterfaces()
        logger.info("utun interfaces BEFORE cleanup: \(utunsBefore.isEmpty ? "none" : utunsBefore.joined(separator: ", "))")
        
        // Log any existing sing-box processes
        let existingPids = findSingBoxProcesses()
        logger.info("Existing sing-box PIDs: \(existingPids.isEmpty ? "none" : existingPids.map(String.init).joined(separator: ", "))")
        // === DIAGNOSTIC LOGGING END ===
        
        // T119: Config switching - stop existing process if running (different or same config)
        if let existingProcess = process, existingProcess.isRunning {
            let oldConfig = self.configPath ?? "unknown"
            logger.info("T119: Switching config - stopping existing process (PID: \(existingProcess.processIdentifier), config: \(oldConfig))")
            
            // Graceful stop with system proxy restore
            try await stopCore()
            
            // Brief wait for resources to be fully released
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        logger.info("Starting sing-box: core=\(corePath), config=\(configPath)")

        // Apply system proxy settings before starting.
        // Priority: explicit IPC payload > inferred from config.
        let proxyToApply = systemProxy ?? requestedSystemProxy(from: configPath)
        if let proxy = proxyToApply {
            do {
                appliedSystemProxySnapshot = try applySystemProxy(proxy)
            } catch {
                logger.error("Failed to apply system proxy: \(error.localizedDescription)")
                // Don't hard-fail start: allow sing-box to run even if proxy couldn't be set.
                // Users can still use per-app proxy or manual settings.
            }
        }
        
        // CRITICAL: Parse config for TUN interface name and ensure it's available
        let tunInterfaceNames = extractTunInterfaceNames(from: configPath)
        logger.info("TUN interfaces from config: \(tunInterfaceNames.isEmpty ? "none" : tunInterfaceNames.joined(separator: ", "))")
        
        // Force release any occupied TUN interfaces BEFORE killing sing-box
        for tunName in tunInterfaceNames {
            if isTunInterfacePresent(tunName) {
                logger.warning("TUN interface \(tunName) is occupied, forcing release...")
                await forceReleaseTunInterface(tunName)
            }
        }
        
        // Kill any stale sing-box processes
        await killStaleSingBoxProcesses()
        
        // Wait for all specified TUN interfaces to be released
        for tunName in tunInterfaceNames {
            await waitForSpecificTunRelease(tunName)
        }
        
        // Also wait for general TUN cleanup
        await waitForTunRelease()
        
        // === DIAGNOSTIC: Log state AFTER cleanup ===
        let utunsAfter = listAllUtunInterfaces()
        logger.info("utun interfaces AFTER cleanup: \(utunsAfter.isEmpty ? "none" : utunsAfter.joined(separator: ", "))")
        let pidsAfter = findSingBoxProcesses()
        logger.info("sing-box PIDs AFTER cleanup: \(pidsAfter.isEmpty ? "none" : pidsAfter.map(String.init).joined(separator: ", "))")
        
        // CRITICAL: If any TUN interface is STILL occupied, patch config to use an available one
        // This is the final fallback to ensure reliable startup
        var finalConfigPath = configPath
        for tunName in tunInterfaceNames {
            if isTunInterfacePresent(tunName) {
                logger.error("TUN interface \(tunName) still occupied after all cleanup attempts!")
                logger.info("Attempting to patch config with an available TUN interface name...")
                
                // Create a patched copy of the config
                if let patchedPath = try? patchConfigWithAvailableTun(configPath: configPath) {
                    finalConfigPath = patchedPath
                    logger.info("Using patched config: \(patchedPath)")
                }
                break
            }
        }
        
        // Reset crash state for new start
        crashed = false
        crashReason = nil
        lastExitCode = nil
        
        // Ensure core is executable
        try ensureExecutable(at: corePath)
        
        // Remove quarantine attribute if present
        removeQuarantine(from: corePath)
        
        // Setup process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: corePath)
        proc.arguments = ["run", "-c", finalConfigPath]
        
        // Set working directory to config directory for relative paths in config
        proc.currentDirectoryURL = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        
        // === DIAGNOSTIC: Log exact command being executed ===
        logger.info("Executing: \(corePath) run -c \(finalConfigPath)")
        logger.info("Working dir: \(proc.currentDirectoryURL?.path ?? "nil")")
        
        // Setup stdout/stderr capture
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr
        
        stdoutPipe = stdout
        stderrPipe = stderr
        
        // Setup log capture
        setupLogCapture(stdout: stdout, stderr: stderr)
        
        // Setup termination handler
        proc.terminationHandler = { [weak self] terminatedProcess in
            Task { [weak self] in
                await self?.handleTermination(exitCode: terminatedProcess.terminationStatus)
            }
        }
        
        // Start process
        do {
            try proc.run()
        } catch {
            logger.error("Failed to start sing-box: \(error.localizedDescription)")
            throw CoreManagerError.startFailed(error.localizedDescription)
        }
        
        let pid = proc.processIdentifier
        logger.info("sing-box started with PID \(pid)")
        
        // Store state
        process = proc
        startTime = Date()
        self.configPath = configPath
        
        // Wait briefly to ensure process didn't crash immediately
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        if !proc.isRunning {
            let exitCode = proc.terminationStatus
            let recentLogs = logBuffer.suffix(20).joined(separator: "\n")
            logger.error("sing-box exited immediately with code \(exitCode)")
            throw CoreManagerError.startFailed("Process exited with code \(exitCode)\n\(recentLogs)")
        }
        
        return pid
    }
    
    /// Stop the running sing-box process
    func stopCore() async throws {
        guard let proc = process, proc.isRunning else {
            logger.info("No running process to stop")
            process = nil
            startTime = nil
            configPath = nil
            // Still wait for any stale TUN cleanup
            await waitForTunRelease()
            return
        }
        
        let pid = proc.processIdentifier
        logger.info("Stopping sing-box (PID \(pid))...")
        
        // Send SIGTERM first (graceful shutdown)
        proc.terminate()
        
        // Wait up to 3 seconds for graceful shutdown
        let deadline = Date().addingTimeInterval(3.0)
        while proc.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        // Force kill if still running
        if proc.isRunning {
            logger.warning("Process didn't terminate gracefully, sending SIGKILL")
            kill(pid, SIGKILL)
            proc.waitUntilExit()
        }
        
        logger.info("sing-box process stopped, waiting for TUN interface release...")
        
        // Clear state
        process = nil
        startTime = nil
        configPath = nil

        // Restore system proxy if we changed it.
        if let snapshot = appliedSystemProxySnapshot {
            do {
                try restoreSystemProxy(from: snapshot)
            } catch {
                logger.error("Failed to restore system proxy: \(error.localizedDescription)")
            }
            appliedSystemProxySnapshot = nil
        }
        
        // CRITICAL: Wait for kernel to fully release TUN interface
        // This is necessary because the kernel may hold the interface briefly after process exit
        await waitForTunRelease()
        
        logger.info("sing-box stopped and resources released")
    }
    
    /// Wait for TUN interface to be released by the kernel
    private func waitForTunRelease() async {
        // Wait for ALL utun interfaces created by sing-box to be released
        // The kernel may hold them briefly after process exit
        logger.debug("Waiting for TUN interfaces to be released...")
        
        for i in 1...20 {  // Up to 4 seconds
            let utuns = listAllUtunInterfaces()
            // If no utun interfaces (other than system ones like utun0-2), we're good
            // System typically uses utun0, utun1, utun2 for built-in services
            let singboxUtuns = utuns.filter { name in
                guard let num = Int(name.dropFirst(4)) else { return false }
                return num >= 3  // utun3+ are likely sing-box
            }
            
            if singboxUtuns.isEmpty {
                logger.debug("TUN interfaces released after \(i * 200)ms")
                return
            }
            
            logger.debug("Still waiting for utun release: \(singboxUtuns.joined(separator: ", "))")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }
        
        logger.warning("Some utun interfaces still present after 4s, may cause issues")
    }
    
    /// List all utun interfaces currently in the system
    private func listAllUtunInterfaces() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return result }
        defer { freeifaddrs(ifaddr) }
        
        var seen = Set<String>()
        var ptr = ifaddr
        while let addr = ptr {
            let ifName = String(cString: addr.pointee.ifa_name)
            if ifName.hasPrefix("utun") && !seen.contains(ifName) {
                seen.insert(ifName)
                result.append(ifName)
            }
            ptr = addr.pointee.ifa_next
        }
        return result.sorted()
    }
    
    /// Find all running sing-box process IDs
    private func findSingBoxProcesses() -> [pid_t] {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-x", "sing-box"]
        
        let pipe = Pipe()
        pgrep.standardOutput = pipe
        pgrep.standardError = FileHandle.nullDevice
        
        do {
            try pgrep.run()
            pgrep.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return output.split(separator: "\n")
                .compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
        } catch {
            return []
        }
    }

    /// Check if a TUN interface is present in the system
    private func isTunInterfacePresent(_ name: String) -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return false }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while let addr = ptr {
            let ifName = String(cString: addr.pointee.ifa_name)
            if ifName == name {
                return true
            }
            ptr = addr.pointee.ifa_next
        }
        return false
    }
    
    /// Kill any stale sing-box processes that might be holding TUN interface
    private func killStaleSingBoxProcesses() async {
        logger.info("=== CLEANUP: Killing stale sing-box processes ===")
        
        // First, find all sing-box processes
        let pids = findSingBoxProcesses()
        if pids.isEmpty {
            logger.info("No stale sing-box processes found via pgrep")
        } else {
            logger.info("Found sing-box PIDs to kill: \(pids.map(String.init).joined(separator: ", "))")
            
            // Kill each one directly with SIGKILL
            for pid in pids {
                logger.info("Sending SIGKILL to PID \(pid)")
                kill(pid, SIGKILL)
            }
            
            // Wait for them to die
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        // Also use killall as backup (catches processes that might have been missed)
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["-9", "sing-box"]
        killall.standardOutput = FileHandle.nullDevice
        killall.standardError = FileHandle.nullDevice
        
        try? killall.run()
        killall.waitUntilExit()
        
        if killall.terminationStatus == 0 {
            logger.info("killall found additional sing-box processes")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        // Final check
        let remainingPids = findSingBoxProcesses()
        if !remainingPids.isEmpty {
            logger.warning("WARNING: sing-box processes still running after cleanup: \(remainingPids.map(String.init).joined(separator: ", "))")
        } else {
            logger.info("All sing-box processes cleaned up")
        }
    }
    
    /// Extract TUN interface names from sing-box config file
    private func extractTunInterfaceNames(from configPath: String) -> [String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]] else {
            return []
        }
        
        var names: [String] = []
        for inbound in inbounds {
            guard (inbound["type"] as? String) == "tun" else { continue }
            if let name = inbound["interface_name"] as? String, !name.isEmpty {
                // Validate interface name (alphanumeric + dash/underscore only)
                let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
                if name.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                    names.append(name)
                }
            }
        }
        return names
    }
    
    /// Force release a specific TUN interface by killing ALL processes using it
    private func forceReleaseTunInterface(_ interfaceName: String) async {
        logger.info("=== FORCE RELEASE: Killing all processes occupying \(interfaceName) ===")
        
        // Method 1: Use lsof to find processes with the interface open
        let pidsFromLsof = findProcessesUsingInterface(interfaceName)
        if !pidsFromLsof.isEmpty {
            logger.info("Found PIDs via lsof: \(pidsFromLsof.map(String.init).joined(separator: ", "))")
            for pid in pidsFromLsof {
                logger.info("Sending SIGKILL to PID \(pid) (lsof)")
                kill(pid, SIGKILL)
            }
        }
        
        // Method 2: Find processes by name that commonly use TUN
        // This catches sing-box, clash, v2ray, etc.
        let tunRelatedProcesses = ["sing-box", "clash", "v2ray", "xray", "trojan", "ss-local", "ssr-local"]
        for processName in tunRelatedProcesses {
            let killProc = Process()
            killProc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProc.arguments = ["-9", processName]
            killProc.standardOutput = FileHandle.nullDevice
            killProc.standardError = FileHandle.nullDevice
            try? killProc.run()
            killProc.waitUntilExit()
            if killProc.terminationStatus == 0 {
                logger.info("Killed \(processName) process(es)")
            }
        }
        
        // Method 3: Use ifconfig to bring down the interface (if still exists)
        if isTunInterfacePresent(interfaceName) {
            logger.info("Interface \(interfaceName) still present, attempting ifconfig down...")
            let ifconfig = Process()
            ifconfig.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
            ifconfig.arguments = [interfaceName, "down"]
            ifconfig.standardOutput = FileHandle.nullDevice
            ifconfig.standardError = FileHandle.nullDevice
            try? ifconfig.run()
            ifconfig.waitUntilExit()
        }
        
        // Wait for kernel to release the interface
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
    }
    
    /// Find all process IDs that have a specific network interface open
    private func findProcessesUsingInterface(_ interfaceName: String) -> [pid_t] {
        // Use lsof to find processes with the interface
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-n", "-P"]  // No name resolution, no port names
        
        let pipe = Pipe()
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice
        
        do {
            try lsof.run()
            lsof.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            var pids = Set<pid_t>()
            for line in output.split(separator: "\n") {
                // lsof output format: COMMAND  PID  USER  FD  TYPE  DEVICE  SIZE/OFF  NODE  NAME
                // We look for lines containing the interface name
                if line.contains(interfaceName) {
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count > 1, let pid = pid_t(parts[1]) {
                        pids.insert(pid)
                    }
                }
            }
            return Array(pids)
        } catch {
            logger.error("lsof failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Wait for a specific TUN interface to be released
    private func waitForSpecificTunRelease(_ interfaceName: String) async {
        logger.info("Waiting for \(interfaceName) to be released...")
        
        for i in 1...30 {  // Up to 6 seconds
            if !isTunInterfacePresent(interfaceName) {
                logger.info("\(interfaceName) released after \(i * 200)ms")
                return
            }
            
            // Every second, try to force release again
            if i % 5 == 0 {
                logger.warning("\(interfaceName) still present after \(i * 200)ms, attempting force release...")
                await forceReleaseTunInterface(interfaceName)
            }
            
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }
        
        // Last resort: log warning but continue (might fail, but let sing-box report the error)
        if isTunInterfacePresent(interfaceName) {
            logger.error("CRITICAL: \(interfaceName) still occupied after 6 seconds of cleanup attempts!")
            // Try one more aggressive cleanup
            await forceReleaseTunInterface(interfaceName)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s final wait
        }
    }
    
    /// Patch the config file to use an available TUN interface name
    /// macOS uses utun* interfaces, and we need to find one that's not in use
    private func patchTunInterfaceName(configPath: String) throws {
        logger.debug("Patching TUN interface name in config...")
        
        let configURL = URL(fileURLWithPath: configPath)
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var inbounds = json["inbounds"] as? [[String: Any]] else {
            logger.debug("Could not parse config for TUN patching, skipping")
            return
        }
        
        var modified = false
        for i in 0..<inbounds.count {
            guard inbounds[i]["type"] as? String == "tun" else { continue }
            
            // Find an available utun interface number (start high to avoid conflicts)
            let availableName = findAvailableUtunName()
            let currentName = inbounds[i]["interface_name"] as? String ?? "unset"
            
            if currentName != availableName {
                inbounds[i]["interface_name"] = availableName
                modified = true
                logger.info("Patched TUN interface: \(currentName) -> \(availableName)")
            }
        }
        
        if modified {
            json["inbounds"] = inbounds
            if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                try? newData.write(to: configURL)
                logger.info("Config file updated with new TUN interface name")
            }
        }
    }
    
    /// Find an available utun interface name that's not in use
    private func findAvailableUtunName() -> String {
        // Get list of existing interfaces
        var existingNames = Set<String>()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            defer { freeifaddrs(ifaddr) }
            var ptr = ifaddr
            while let addr = ptr {
                let name = String(cString: addr.pointee.ifa_name)
                if name.hasPrefix("utun") {
                    existingNames.insert(name)
                }
                ptr = addr.pointee.ifa_next
            }
        }
        
        // Find first available utun starting from 199 (to avoid low numbers used by system)
        for n in 199...999 {
            let name = "utun\(n)"
            if !existingNames.contains(name) {
                return name
            }
        }
        
        // Fallback - let sing-box choose (empty string or auto)
        return "utun199"
    }
    
    /// Create a patched copy of config with an available TUN interface name
    /// Returns the path to the patched config file
    private func patchConfigWithAvailableTun(configPath: String) throws -> String {
        logger.info("Creating patched config with available TUN interface...")
        
        let configURL = URL(fileURLWithPath: configPath)
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var inbounds = json["inbounds"] as? [[String: Any]] else {
            throw CoreManagerError.startFailed("Could not parse config for TUN patching")
        }
        
        let availableName = findAvailableUtunName()
        var modified = false
        
        for i in 0..<inbounds.count {
            guard inbounds[i]["type"] as? String == "tun" else { continue }
            
            let currentName = inbounds[i]["interface_name"] as? String ?? "unset"
            inbounds[i]["interface_name"] = availableName
            modified = true
            logger.info("Patching TUN interface: \(currentName) -> \(availableName)")
        }
        
        guard modified else {
            // No TUN inbound found, return original
            return configPath
        }
        
        json["inbounds"] = inbounds
        
        // Write to a temporary patched file (don't modify original)
        let patchedURL = configURL.deletingPathExtension().appendingPathExtension("patched.json")
        
        guard let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else {
            throw CoreManagerError.startFailed("Could not serialize patched config")
        }
        
        try newData.write(to: patchedURL)
        logger.info("Patched config written to: \(patchedURL.path)")
        
        return patchedURL.path
    }
    
    /// Get current status
    nonisolated func getStatus() -> StatusData {
        // Return basic status - for full status use async version
        // This is safe because we're just reading state that won't cause data races
        // In practice the caller should use the async version when possible
        return StatusData.stopped()
    }
    
    /// Get current status (async version with full data)
    func getStatusAsync() async -> StatusData {
        guard let proc = process, proc.isRunning else {
            // T067: Return crash info if crashed
            if crashed {
                return StatusData.crashed(exitCode: lastExitCode ?? -1, reason: crashReason)
            }
            return StatusData.stopped()
        }
        
        return StatusData(
            isRunning: true,
            pid: proc.processIdentifier,
            configPath: configPath,
            startTime: startTime,
            uptimeSeconds: startTime.map { Int(Date().timeIntervalSince($0)) },
            lastExitCode: nil,
            errorReason: nil
        )
    }
    
    /// Get recent log lines
    nonisolated func getRecentLogs() -> [String] {
        // Return empty for sync access - use async version for actual logs
        return []
    }
    
    /// Get recent log lines (async version with actual data)
    func getRecentLogsAsync() async -> [String] {
        return Array(logBuffer.suffix(100))
    }
    
    // MARK: - Private Methods
    
    private func ensureExecutable(at path: String) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            throw CoreManagerError.binaryNotFound(path)
        }
        
        // Check if executable
        if !fileManager.isExecutableFile(atPath: path) {
            // Try to make it executable
            do {
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            } catch {
                throw CoreManagerError.notExecutable(path)
            }
        }
    }
    
    private func removeQuarantine(from path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-d", "com.apple.quarantine", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try? process.run()
        process.waitUntilExit()
    }
    
    private func setupLogCapture(stdout: Pipe, stderr: Pipe) {
        // Read stdout
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                Task { [weak self] in
                    await self?.appendLog(line)
                }
            }
        }
        
        // Read stderr
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                Task { [weak self] in
                    await self?.appendLog(line)
                }
            }
        }
    }
    
    private func appendLog(_ line: String) {
        // Split by newlines and add timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let lines = line.split(separator: "\n", omittingEmptySubsequences: false)
        
        for subline in lines where !subline.isEmpty {
            logBuffer.append("[\(timestamp)] \(subline)")
        }
        
        // Trim buffer if too large
        if logBuffer.count > maxLogLines {
            logBuffer.removeFirst(logBuffer.count - maxLogLines)
        }
    }
    
    private func handleTermination(exitCode: Int32) {
        logger.info("sing-box terminated with exit code \(exitCode)")
        
        // T067: Track crash state
        lastExitCode = exitCode
        
        if exitCode != 0 {
            crashed = true
            let recentLogs = logBuffer.suffix(5).joined(separator: " | ")
            crashReason = "Exit code: \(exitCode). Recent: \(recentLogs)"
            appendLog("[SERVICE] sing-box crashed with code \(exitCode)")
        } else {
            // Normal exit (graceful stop)
            crashed = false
            crashReason = nil
        }
        
        // Clean up pipe handlers
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil

        // Best-effort restore proxy if sing-box crashed.
        if let snapshot = appliedSystemProxySnapshot {
            do {
                try restoreSystemProxy(from: snapshot)
            } catch {
                logger.error("Failed to restore system proxy after termination: \(error.localizedDescription)")
            }
            appliedSystemProxySnapshot = nil
        }
    }
}

// MARK: - System Proxy (networksetup)

private extension CoreManager {

    struct ProxySnapshot: Sendable {
        let web: ProxyState
        let secureWeb: ProxyState
        let bypassDomains: [String]
    }

    struct ProxyState: Sendable {
        let enabled: Bool
        let server: String
        let port: Int
    }

    func requestedSystemProxy(from configPath: String) -> SystemProxySettings? {
        // For now: infer from sing-box config file.
        // If any TUN inbound has platform.http_proxy.enabled == true, request proxy.
        // Default to 127.0.0.1:<server_port>.
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = root["inbounds"] as? [[String: Any]] else {
            return nil
        }

        for inbound in inbounds {
            guard (inbound["type"] as? String) == "tun" else { continue }
            guard let platform = inbound["platform"] as? [String: Any],
                  let httpProxy = platform["http_proxy"] as? [String: Any] else {
                continue
            }
            guard (httpProxy["enabled"] as? Bool) == true else { continue }

            let host = (httpProxy["server"] as? String) ?? "127.0.0.1"
            if let port = httpProxy["server_port"] as? Int {
                return SystemProxySettings(enabled: true, host: host, port: port, bypassDomains: ["localhost", "127.0.0.1"])
            }
        }
        return nil
    }

    func applySystemProxy(_ settings: SystemProxySettings) throws -> [String: ProxySnapshot] {
        let services = try listNetworkServices()
        var snapshots: [String: ProxySnapshot] = [:]

        for service in services {
            let web = try getProxyState(kind: .web, service: service)
            let secure = try getProxyState(kind: .secureWeb, service: service)
            let bypass = try getBypassDomains(service: service)
            snapshots[service] = ProxySnapshot(web: web, secureWeb: secure, bypassDomains: bypass)

            if settings.enabled {
                try setProxy(kind: .web, service: service, host: settings.host, port: settings.port, enabled: true)
                try setProxy(kind: .secureWeb, service: service, host: settings.host, port: settings.port, enabled: true)
                if let bypassDomains = settings.bypassDomains, !bypassDomains.isEmpty {
                    try setBypassDomains(service: service, domains: bypassDomains)
                }
            } else {
                try setProxy(kind: .web, service: service, host: settings.host, port: settings.port, enabled: false)
                try setProxy(kind: .secureWeb, service: service, host: settings.host, port: settings.port, enabled: false)
            }
        }

        return snapshots
    }

    func restoreSystemProxy(from snapshot: [String: ProxySnapshot]) throws {
        for (service, snap) in snapshot {
            try setProxy(kind: .web, service: service, host: snap.web.server, port: snap.web.port, enabled: snap.web.enabled)
            try setProxy(kind: .secureWeb, service: service, host: snap.secureWeb.server, port: snap.secureWeb.port, enabled: snap.secureWeb.enabled)
            try setBypassDomains(service: service, domains: snap.bypassDomains)
        }
    }

    enum ProxyKind {
        case web
        case secureWeb
    }

    func listNetworkServices() throws -> [String] {
        let output = try runNetworksetup(arguments: ["-listallnetworkservices"])
        let lines = output.split(separator: "\n").map { String($0) }
        // First line is a header: "An asterisk (*) denotes that a network service is disabled."
        return lines.dropFirst().compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            // Skip disabled services (prefixed with "*")
            if line.hasPrefix("*") { return nil }
            return line
        }
    }

    func getProxyState(kind: ProxyKind, service: String) throws -> ProxyState {
        let args: [String]
        switch kind {
        case .web: args = ["-getwebproxy", service]
        case .secureWeb: args = ["-getsecurewebproxy", service]
        }
        let output = try runNetworksetup(arguments: args)
        var enabled = false
        var server = ""
        var port = 0
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("Enabled:") {
                enabled = line.localizedCaseInsensitiveContains("Yes")
            } else if line.hasPrefix("Server:") {
                server = line.replacingOccurrences(of: "Server:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Port:") {
                let p = line.replacingOccurrences(of: "Port:", with: "").trimmingCharacters(in: .whitespaces)
                port = Int(p) ?? 0
            }
        }
        return ProxyState(enabled: enabled, server: server, port: port)
    }

    func setProxy(kind: ProxyKind, service: String, host: String, port: Int, enabled: Bool) throws {
        switch kind {
        case .web:
            _ = try runNetworksetup(arguments: ["-setwebproxy", service, host, String(port)])
            _ = try runNetworksetup(arguments: ["-setwebproxystate", service, enabled ? "on" : "off"])
        case .secureWeb:
            _ = try runNetworksetup(arguments: ["-setsecurewebproxy", service, host, String(port)])
            _ = try runNetworksetup(arguments: ["-setsecurewebproxystate", service, enabled ? "on" : "off"])
        }
    }

    func getBypassDomains(service: String) throws -> [String] {
        let output = try runNetworksetup(arguments: ["-getproxybypassdomains", service])
        let domains = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return domains
    }

    func setBypassDomains(service: String, domains: [String]) throws {
        // networksetup expects each domain as a separate argument.
        _ = try runNetworksetup(arguments: ["-setproxybypassdomains", service] + domains)
    }

    func runNetworksetup(arguments: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err

        try proc.run()
        proc.waitUntilExit()

        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if proc.terminationStatus != 0 {
            throw CoreManagerError.startFailed("networksetup failed: \(arguments.joined(separator: " "))\n\n\(stderr.isEmpty ? stdout : stderr)")
        }
        return stdout
    }
}

// MARK: - Errors

enum CoreManagerError: LocalizedError {
    case binaryNotFound(String)
    case notExecutable(String)
    case startFailed(String)
    case alreadyRunning
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "Core binary not found: \(path)"
        case .notExecutable(let path):
            return "Core binary is not executable: \(path)"
        case .startFailed(let reason):
            return "Failed to start core: \(reason)"
        case .alreadyRunning:
            return "Core is already running"
        }
    }
}

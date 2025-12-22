//
//  PacketTunnelProvider.swift
//  SilentX.System
//
//  Packet tunnel provider for the system extension
//  Handles VPN tunnel lifecycle and sing-box integration
//

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = Logger(subsystem: "Silent-Net.SilentX.System", category: "PacketTunnelProvider")
    private var process: Process?
    private var configPath: String?
    
    // MARK: - Tunnel Lifecycle
    
    override func startTunnel(options: [String: NSObject]?) async throws {
        logger.info("Starting tunnel...")
        
        // Get config path from options
        guard let configPathObject = options?["ConfigPath"] as? String else {
            logger.error("Missing ConfigPath in start options")
            throw NEVPNError(.configurationInvalid)
        }
        configPath = configPathObject
        logger.info("Config path: \(configPathObject)")
        
        // Get username for accessing user's files
        let username: String
        if let usernameObject = options?["username"] as? String {
            username = usernameObject
        } else {
            username = NSUserName()
        }
        logger.info("Username: \(username)")
        
        // Setup paths for App Group container
        let groupContainer = "/Users/\(username)/Library/Group Containers/group.Silent-Net.SilentX"
        let sharedConfigPath = "\(groupContainer)/active-config.json"
        
        // Read the config
        guard FileManager.default.fileExists(atPath: sharedConfigPath) else {
            logger.error("Config file not found at: \(sharedConfigPath)")
            throw NEVPNError(.configurationInvalid)
        }
        
        // Find sing-box binary
        let coresDir = "/Users/\(username)/Library/Application Support/Silent-Net.SilentX/cores"
        let singboxPath = findSingBoxBinary(in: coresDir)
        
        guard let singboxPath = singboxPath else {
            logger.error("sing-box binary not found in: \(coresDir)")
            throw NEVPNError(.configurationInvalid)
        }
        
        logger.info("Found sing-box at: \(singboxPath)")
        
        // Start sing-box process
        do {
            try await startSingBox(binaryPath: singboxPath, configPath: sharedConfigPath)
            logger.info("Tunnel started successfully")
        } catch {
            logger.error("Failed to start sing-box: \(error.localizedDescription)")
            throw error
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason) async {
        logger.info("Stopping tunnel, reason: \(String(describing: reason))")
        
        // Stop sing-box process
        if let process = process, process.isRunning {
            process.terminate()
            
            // Wait for graceful shutdown
            let deadline = Date().addingTimeInterval(3.0)
            while process.isRunning && Date() < deadline {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            
            // Force kill if still running
            if process.isRunning {
                process.interrupt()
            }
        }
        
        process = nil
        logger.info("Tunnel stopped")
    }
    
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        // Handle IPC messages from the main app
        logger.debug("Received app message: \(messageData.count) bytes")
        return messageData
    }
    
    override func sleep() async {
        logger.info("System going to sleep")
        // Pause network operations if needed
    }
    
    override func wake() {
        logger.info("System waking up")
        // Resume network operations
    }
    
    // MARK: - Private Methods
    
    private func findSingBoxBinary(in directory: String) -> String? {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }
        
        // Look for version directories
        for versionDir in contents {
            let binaryPath = "\(directory)/\(versionDir)/sing-box"
            if fileManager.isExecutableFile(atPath: binaryPath) {
                return binaryPath
            }
        }
        
        return nil
    }
    
    private func startSingBox(binaryPath: String, configPath: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["run", "-c", configPath]
        process.currentDirectoryURL = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        
        // Capture stdout/stderr for logging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Start background readers for logs
        Task {
            for try await line in outputPipe.fileHandleForReading.bytes.lines {
                logger.info("sing-box: \(line)")
            }
        }
        
        Task {
            for try await line in errorPipe.fileHandleForReading.bytes.lines {
                logger.warning("sing-box stderr: \(line)")
            }
        }
        
        do {
            try process.run()
            self.process = process
            
            // Wait briefly for process to initialize
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            if !process.isRunning {
                throw NEVPNError(.connectionFailed)
            }
            
        } catch {
            logger.error("Failed to start process: \(error.localizedDescription)")
            throw NEVPNError(.connectionFailed)
        }
    }
}

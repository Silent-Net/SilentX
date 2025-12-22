//
//  PacketTunnelProvider.swift
//  SilentX-Extension
//
//  Network Extension for SilentX VPN tunnel
//

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = Logger(subsystem: "Silent-Net.SilentX-Extension", category: "PacketTunnelProvider")
    private var singboxProcess: Process?
    
    // MARK: - Tunnel Lifecycle (Completion Handler Based - avoids Swift compiler bug)
    
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting tunnel...")
        
        // Get username for accessing user's files
        let username = (options?["username"] as? String) ?? NSUserName()
        logger.info("Username: \(username)")
        
        // Setup paths for App Group container
        guard let groupContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.Silent-Net.SilentX"
        ) else {
            logger.error("Failed to get App Group container")
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }
        
        let sharedConfigPath = groupContainer.appendingPathComponent("active-config.json")
        
        // Check config exists
        guard FileManager.default.fileExists(atPath: sharedConfigPath.path) else {
            logger.error("Config file not found at: \(sharedConfigPath.path)")
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }
        
        // Find sing-box binary
        let coresDir = "/Users/\(username)/Library/Application Support/Silent-Net.SilentX/cores"
        guard let singboxPath = findSingBoxBinary(in: coresDir) else {
            logger.error("sing-box binary not found in: \(coresDir)")
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }
        
        logger.info("Found sing-box at: \(singboxPath)")
        
        // Start sing-box process
        do {
            try launchSingBox(binaryPath: singboxPath, configPath: sharedConfigPath.path)
            
            // Wait briefly for process to initialize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else {
                    completionHandler(NEVPNError(.connectionFailed))
                    return
                }
                
                if self.singboxProcess?.isRunning == true {
                    self.logger.info("Tunnel started successfully")
                    completionHandler(nil)
                } else {
                    self.logger.error("sing-box process failed to start")
                    completionHandler(NEVPNError(.connectionFailed))
                }
            }
        } catch {
            logger.error("Failed to start sing-box: \(error.localizedDescription)")
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping tunnel, reason: \(reason.rawValue)")
        
        if let process = singboxProcess, process.isRunning {
            process.terminate()
            
            // Give it time to stop gracefully, then force if needed
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if process.isRunning {
                    process.interrupt()
                }
                self?.singboxProcess = nil
                self?.logger.info("Tunnel stopped")
                completionHandler()
            }
        } else {
            singboxProcess = nil
            logger.info("Tunnel already stopped")
            completionHandler()
        }
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        logger.debug("Received app message: \(messageData.count) bytes")
        completionHandler?(messageData)
    }
    
    // MARK: - Private Methods
    
    private func findSingBoxBinary(in directory: String) -> String? {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }
        
        for versionDir in contents {
            let binaryPath = "\(directory)/\(versionDir)/sing-box"
            if fileManager.isExecutableFile(atPath: binaryPath) {
                return binaryPath
            }
        }
        
        return nil
    }
    
    private func launchSingBox(binaryPath: String, configPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["run", "-c", configPath]
        process.currentDirectoryURL = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        
        // Redirect output to null to avoid buffer issues
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        self.singboxProcess = process
        
        logger.info("Started sing-box process with PID: \(process.processIdentifier)")
    }
}

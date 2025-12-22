//
//  main.swift
//  SilentX-Service
//
//  Entry point for the SilentX Privileged Helper Service
//  This service runs as a LaunchDaemon with root privileges
//  and manages the sing-box proxy process.
//

import Foundation
import os.log

// MARK: - Service Constants

let serviceVersion = "1.0.0"
let serviceBuildDate = "2025-01-01"

// MARK: - Logging

let logger = Logger(subsystem: "com.silentnet.silentx.service", category: "main")

// MARK: - Global State (for signal handlers)

/// Global reference to core manager for signal handlers
/// Signal handlers cannot capture context, so we need a global
nonisolated(unsafe) var globalCoreManager: CoreManager?
nonisolated(unsafe) var isShuttingDown = false

// MARK: - Signal Handling

/// Install signal handlers for graceful shutdown
func setupSignalHandlers() {
    // Handle SIGTERM (sent by launchctl stop)
    signal(SIGTERM) { _ in
        guard !isShuttingDown else { return }
        isShuttingDown = true
        logger.info("Received SIGTERM, initiating graceful shutdown...")
        
        if let manager = globalCoreManager {
            Task {
                do {
                    try await manager.stopCore()
                } catch {
                    // Log handled in stopCore
                }
                exit(0)
            }
        } else {
            exit(0)
        }
    }
    
    // Handle SIGINT (Ctrl+C in terminal)
    signal(SIGINT) { _ in
        guard !isShuttingDown else { return }
        isShuttingDown = true
        logger.info("Received SIGINT, initiating graceful shutdown...")
        
        if let manager = globalCoreManager {
            Task {
                do {
                    try await manager.stopCore()
                } catch {
                    // Log handled in stopCore
                }
                exit(0)
            }
        } else {
            exit(0)
        }
    }
}

// MARK: - Runtime Directory Setup

/// Ensure runtime directory exists with correct permissions
func setupRuntimeDirectory() throws {
    let runtimeDir = "/tmp/silentx"
    let fileManager = FileManager.default
    
    if !fileManager.fileExists(atPath: runtimeDir) {
        try fileManager.createDirectory(atPath: runtimeDir, withIntermediateDirectories: true)
    }
    
    // Set permissions to 0777 so unprivileged apps can access
    var attributes = [FileAttributeKey: Any]()
    attributes[.posixPermissions] = 0o777
    try fileManager.setAttributes(attributes, ofItemAtPath: runtimeDir)
    
    logger.info("Runtime directory ready: \(runtimeDir)")
}

// MARK: - Main Entry Point

logger.info("SilentX Service v\(serviceVersion) starting...")

do {
    // Setup runtime directory
    try setupRuntimeDirectory()
    
    // Create core manager and store globally for signal handlers
    let coreManager = CoreManager()
    globalCoreManager = coreManager
    
    // Setup signal handlers for graceful shutdown
    setupSignalHandlers()
    
    // Create and start IPC server
    let server = IPCServer(coreManager: coreManager)
    try server.start()
    
    logger.info("Service started successfully, listening for connections")
    
    // Run forever (until signal received)
    RunLoop.main.run()
    
} catch {
    logger.error("Failed to start service: \(error.localizedDescription)")
    exit(1)
}

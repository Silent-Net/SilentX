//
//  ServiceInstaller.swift
//  SilentX
//
//  Handles installation and uninstallation of the privileged helper service
//

import Foundation
import os.log

// MARK: - ServiceInstaller

/// Manages installation, uninstallation, and status checking of the privileged helper service
final class ServiceInstaller {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "ServiceInstaller")
    
    // MARK: - Singleton
    
    static let shared = ServiceInstaller()
    
    private init() {}
    
    // MARK: - Status Checking
    
    /// Check if the service is installed (plist exists)
    func isInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: ServicePaths.plistPath)
    }
    
    /// Check if the service is running (responds to ping)
    func isRunning() async -> Bool {
        return await IPCClient.isServiceAvailable()
    }
    
    /// Get comprehensive service status
    func getStatus() async -> ServiceStatus {
        let installed = isInstalled()
        let running = await isRunning()
        
        var version: String? = nil
        if running {
            let client = IPCClient()
            if let versionData = try? await client.version() {
                version = versionData.version
            }
        }
        
        return ServiceStatus(
            isInstalled: installed,
            isRunning: running,
            version: version,
            plistPath: installed ? ServicePaths.plistPath : nil,
            binaryPath: FileManager.default.fileExists(atPath: ServicePaths.binaryPath) ? ServicePaths.binaryPath : nil
        )
    }
    
    // MARK: - Installation
    
    /// Install the privileged helper service
    /// - Throws: ServiceInstallerError if installation fails
    /// - Note: This will prompt for admin password via osascript
    func install() async throws {
        logger.info("Starting service installation...")
        
        // Get bundled resources
        guard let binaryPath = ServicePaths.bundledBinaryPath else {
            throw ServiceInstallerError.binaryNotBundled
        }
        
        guard let plistPath = ServicePaths.bundledPlistTemplatePath else {
            throw ServiceInstallerError.plistNotBundled
        }
        
        guard let installScript = ServicePaths.bundledInstallScriptPath else {
            throw ServiceInstallerError.scriptNotBundled
        }
        
        // Verify bundled files exist
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw ServiceInstallerError.binaryNotFound(binaryPath)
        }
        
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw ServiceInstallerError.plistNotFound(plistPath)
        }
        
        guard FileManager.default.fileExists(atPath: installScript) else {
            throw ServiceInstallerError.scriptNotFound(installScript)
        }
        
        logger.debug("Bundled binary: \(binaryPath)")
        logger.debug("Bundled plist: \(plistPath)")
        logger.debug("Install script: \(installScript)")
        
        // Run install script with admin privileges
        try await runWithAdminPrivileges(
            script: installScript,
            arguments: [binaryPath, plistPath]
        )
        
        // Verify installation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        guard isInstalled() else {
            throw ServiceInstallerError.installFailed("Plist not found after installation")
        }
        
        // Wait for service to start
        var attempts = 0
        while attempts < 10 {
            if await isRunning() {
                logger.info("Service installed and running successfully")
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        logger.warning("Service installed but not responding - may need manual start")
    }
    
    /// Uninstall the privileged helper service
    /// - Throws: ServiceInstallerError if uninstallation fails
    /// - Note: This will prompt for admin password via osascript
    func uninstall() async throws {
        logger.info("Starting service uninstallation...")
        
        guard isInstalled() else {
            logger.info("Service not installed, nothing to uninstall")
            return
        }
        
        guard let uninstallScript = ServicePaths.bundledUninstallScriptPath else {
            throw ServiceInstallerError.scriptNotBundled
        }
        
        guard FileManager.default.fileExists(atPath: uninstallScript) else {
            throw ServiceInstallerError.scriptNotFound(uninstallScript)
        }
        
        // Run uninstall script with admin privileges
        try await runWithAdminPrivileges(
            script: uninstallScript,
            arguments: []
        )
        
        // Verify uninstallation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if isInstalled() {
            throw ServiceInstallerError.uninstallFailed("Plist still exists after uninstallation")
        }
        
        logger.info("Service uninstalled successfully")
    }
    
    /// Reinstall the service (uninstall then install) in ONE password prompt
    func reinstall() async throws {
        logger.info("Reinstalling service (single password)...")
        
        // Get bundle paths
        guard let binaryPath = ServicePaths.bundledBinaryPath else {
            throw ServiceInstallerError.binaryNotBundled
        }
        
        guard let plistPath = ServicePaths.bundledPlistTemplatePath else {
            throw ServiceInstallerError.plistNotBundled
        }
        
        // Try reinstall script first (single password)
        if let reinstallScript = ServicePaths.bundledReinstallScriptPath,
           FileManager.default.fileExists(atPath: reinstallScript) {
            logger.info("Using reinstall script for single-password operation")
            try await runWithAdminPrivileges(
                script: reinstallScript,
                arguments: [binaryPath, plistPath]
            )
        } else {
            // Fallback to separate uninstall + install (two passwords)
            logger.warning("Reinstall script not found, falling back to separate operations")
            if isInstalled() {
                try await uninstall()
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            try await install()
        }
        
        // Verify installation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        guard isInstalled() else {
            throw ServiceInstallerError.installFailed("Plist not found after reinstallation")
        }
        
        // Wait for service to start
        var attempts = 0
        while attempts < 10 {
            if await isRunning() {
                logger.info("Service reinstalled and running successfully")
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        logger.warning("Service reinstalled but not responding")
    }
    
    // MARK: - Private Methods
    
    private func runWithAdminPrivileges(script: String, arguments: [String]) async throws {
        // Build the shell command
        // Use single quotes for arguments to avoid escaping issues
        var shellArgs = [script]
        shellArgs.append(contentsOf: arguments)
        
        // Build the command string with proper escaping
        // We use single quotes for the outer shell, and escape any single quotes in paths
        func shellEscape(_ str: String) -> String {
            // Replace single quotes with '\'' (end quote, escaped quote, start quote)
            return str.replacingOccurrences(of: "'", with: "'\\''")
        }
        
        var command = "/bin/sh"
        for arg in shellArgs {
            command += " '\(shellEscape(arg))'"
        }
        
        // For AppleScript, escape backslashes and double quotes
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        // Build AppleScript
        let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        logger.debug("Running AppleScript: \(appleScript)")
        
        // Run via osascript
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", appleScript]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus != 0 {
                        // Check if user cancelled
                        if errorOutput.contains("canceled") || errorOutput.contains("cancelled") || errorOutput.contains("-128") {
                            continuation.resume(throwing: ServiceInstallerError.userCancelled)
                        } else {
                            self.logger.error("Script failed: \(errorOutput)")
                            continuation.resume(throwing: ServiceInstallerError.scriptFailed(errorOutput))
                        }
                    } else {
                        if !output.isEmpty {
                            self.logger.debug("Script output: \(output)")
                        }
                        continuation.resume()
                    }
                    
                } catch {
                    self.logger.error("Failed to run osascript: \(error.localizedDescription)")
                    continuation.resume(throwing: ServiceInstallerError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
}

// MARK: - ServiceStatus

/// Status information about the privileged helper service
struct ServiceStatus {
    let isInstalled: Bool
    let isRunning: Bool
    let version: String?
    let plistPath: String?
    let binaryPath: String?
    
    var displayText: String {
        if !isInstalled {
            return "Not Installed"
        } else if isRunning {
            if let version = version {
                return "Running (v\(version))"
            }
            return "Running"
        } else {
            return "Installed (Not Running)"
        }
    }
    
    var statusColor: String {
        if !isInstalled {
            return "gray"
        } else if isRunning {
            return "green"
        } else {
            return "orange"
        }
    }
}

// MARK: - Errors

enum ServiceInstallerError: LocalizedError {
    case binaryNotBundled
    case plistNotBundled
    case scriptNotBundled
    case binaryNotFound(String)
    case plistNotFound(String)
    case scriptNotFound(String)
    case scriptFailed(String)
    case executionFailed(String)
    case userCancelled
    case installFailed(String)
    case uninstallFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotBundled:
            return "Service binary not found in app bundle"
        case .plistNotBundled:
            return "LaunchDaemon plist not found in app bundle"
        case .scriptNotBundled:
            return "Installation script not found in app bundle"
        case .binaryNotFound(let path):
            return "Service binary not found at: \(path)"
        case .plistNotFound(let path):
            return "LaunchDaemon plist not found at: \(path)"
        case .scriptNotFound(let path):
            return "Script not found at: \(path)"
        case .scriptFailed(let reason):
            return "Installation script failed: \(reason)"
        case .executionFailed(let reason):
            return "Failed to execute installation: \(reason)"
        case .userCancelled:
            return "Installation cancelled by user"
        case .installFailed(let reason):
            return "Installation failed: \(reason)"
        case .uninstallFailed(let reason):
            return "Uninstallation failed: \(reason)"
        }
    }
    
    /// Whether this error indicates user cancellation (should not show error alert)
    var isUserCancellation: Bool {
        if case .userCancelled = self {
            return true
        }
        return false
    }
}

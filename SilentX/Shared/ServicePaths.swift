//
//  ServicePaths.swift
//  SilentX
//
//  Path constants for the Privileged Helper Service
//

import Foundation

/// Path constants for the SilentX Privileged Helper Service
enum ServicePaths {
    
    // MARK: - Service Identifiers
    
    /// Service bundle identifier
    static let serviceIdentifier = "com.silentnet.silentx.service"
    
    /// Service display name
    static let serviceName = "silentx-service"
    
    // MARK: - System Paths (Installation Locations)
    
    /// LaunchDaemon plist file path
    /// Location: /Library/LaunchDaemons/com.silentnet.silentx.service.plist
    static let plistPath: String = "/Library/LaunchDaemons/\(serviceIdentifier).plist"
    
    /// Directory for privileged helper tools
    /// Location: /Library/PrivilegedHelperTools/com.silentnet.silentx.service/
    static let binaryDirectory: String = "/Library/PrivilegedHelperTools/\(serviceIdentifier)"
    
    /// Full path to the installed service binary
    /// Location: /Library/PrivilegedHelperTools/com.silentnet.silentx.service/silentx-service
    static let binaryPath: String = "\(binaryDirectory)/\(serviceName)"
    
    // MARK: - Runtime Paths (Temporary)
    
    /// Base directory for runtime files
    /// Location: /tmp/silentx/
    static let runtimeDirectory: String = "/tmp/silentx"
    
    /// Unix socket path for IPC
    /// Location: /tmp/silentx/silentx-service.sock
    static let socketPath: String = "\(runtimeDirectory)/\(serviceName).sock"
    
    /// Service log file path
    /// Location: /tmp/silentx/silentx-service.log
    static let serviceLogPath: String = "\(runtimeDirectory)/\(serviceName).log"
    
    /// sing-box stdout/stderr log file
    /// Location: /tmp/silentx/sing-box.log
    static let coreLogPath: String = "\(runtimeDirectory)/sing-box.log"
    
    // MARK: - Bundle Paths (App Resources)
    
    /// Path to bundled service binary in app bundle
    static var bundledBinaryPath: String? {
        Bundle.main.path(forResource: serviceName, ofType: nil)
    }
    
    /// Path to bundled install script in app bundle
    static var bundledInstallScriptPath: String? {
        Bundle.main.path(forResource: "install-service", ofType: "sh")
    }
    
    /// Path to bundled uninstall script in app bundle
    static var bundledUninstallScriptPath: String? {
        Bundle.main.path(forResource: "uninstall-service", ofType: "sh")
    }
    
    /// Path to bundled reinstall script in app bundle (uninstall + install in one sudo)
    static var bundledReinstallScriptPath: String? {
        Bundle.main.path(forResource: "reinstall-service", ofType: "sh")
    }
    
    /// Path to bundled launchd plist template in app bundle
    static var bundledPlistTemplatePath: String? {
        Bundle.main.path(forResource: "launchd.plist", ofType: "template")
    }
    
    // MARK: - URL Helpers
    
    /// Socket path as URL for NWConnection
    static var socketURL: URL {
        URL(fileURLWithPath: socketPath)
    }
    
    /// Plist path as URL
    static var plistURL: URL {
        URL(fileURLWithPath: plistPath)
    }
    
    /// Binary path as URL
    static var binaryURL: URL {
        URL(fileURLWithPath: binaryPath)
    }
    
    /// Runtime directory as URL
    static var runtimeDirectoryURL: URL {
        URL(fileURLWithPath: runtimeDirectory)
    }
}

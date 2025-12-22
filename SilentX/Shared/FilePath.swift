//
//  FilePath.swift
//  SilentX
//
//  Shared file path constants for application directories
//

import Foundation

/// File path constants for SilentX application directories
enum FilePath {
    
    // MARK: - Constants
    
    /// Bundle identifier for the main app
    static let packageName = "Silent-Net.SilentX"
    
    /// App Group identifier for sharing data with system extension
    static let groupIdentifier = "group.Silent-Net.SilentX"
    
    // MARK: - App Group Directories (T057-T058)
    
    /// Shared container for App Group (used by both main app and system extension)
    static let sharedDirectory: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }()
    
    /// Active configuration file path in shared container
    static let sharedConfigPath: URL? = {
        sharedDirectory?.appendingPathComponent("active-config.json")
    }()
    
    /// Shared settings path in App Group
    static let sharedSettingsPath: URL? = {
        sharedDirectory?.appendingPathComponent("settings.db")
    }()
    
    /// Cache directory within App Group
    static let sharedCacheDirectory: URL? = {
        guard let shared = sharedDirectory else { return nil }
        let url = shared.appendingPathComponent("Library/Caches", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    /// Working directory for sing-box runtime files in App Group
    static let sharedWorkingDirectory: URL? = {
        guard let cache = sharedCacheDirectory else { return nil }
        let url = cache.appendingPathComponent("Working", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    // MARK: - Base Directories
    
    /// Application Support directory for SilentX
    static let applicationSupport: URL = {
        // Align with CoreVersionService download path: ~/Library/Application Support/Silent-Net.SilentX/
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Silent-Net.SilentX", isDirectory: true)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        return url
    }()
    
    /// Profiles directory for storing profile JSON files
    static let profiles: URL = {
        let url = applicationSupport.appendingPathComponent("profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    /// Cores directory for cached Sing-Box binaries
    static let cores: URL = {
        let url = applicationSupport.appendingPathComponent("cores", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    /// Logs directory for exported logs
    static let logs: URL = {
        let url = applicationSupport.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Runtime directory for generated (launch) configs and transient state
    static let runtime: URL = {
        let url = applicationSupport.appendingPathComponent("runtime", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    // MARK: - Helper Methods
    
    /// Get the path for a specific profile file
    static func profilePath(for id: UUID) -> URL {
        profiles.appendingPathComponent("\(id.uuidString).json")
    }

    /// Get the path for the generated runtime config used to launch sing-box
    static func runtimeConfigPath(for id: UUID) -> URL {
        runtime.appendingPathComponent("\(id.uuidString).runtime.json")
    }
    
    /// Get the path for a specific core version directory
    static func corePath(for version: String) -> URL {
        cores.appendingPathComponent(version, isDirectory: true)
    }
    
    /// Get the path for the Sing-Box binary of a specific version
    static func singBoxBinary(for version: String) -> URL {
        corePath(for: version).appendingPathComponent("sing-box")
    }
}

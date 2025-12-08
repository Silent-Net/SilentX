//
//  FilePath.swift
//  SilentX
//
//  Shared file path constants for application directories
//

import Foundation

/// File path constants for SilentX application directories
enum FilePath {
    
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
    
    // MARK: - Helper Methods
    
    /// Get the path for a specific profile file
    static func profilePath(for id: UUID) -> URL {
        profiles.appendingPathComponent("\(id.uuidString).json")
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

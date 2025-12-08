//
//  Constants.swift
//  SilentX
//
//  App-wide constants and configuration values
//

import Foundation

/// App-wide constants for SilentX
enum Constants {
    
    // MARK: - App Info
    
    /// Application name
    static let appName = "SilentX"
    
    /// Bundle identifier
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.silentnet.silentx"
    
    /// Current app version
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Build number
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Sing-Box
    
    /// Default Sing-Box version to use
    static let defaultSingBoxVersion = "1.12.12"
    
    /// GitHub repository for Sing-Box releases
    static let singBoxGitHubRepo = "SagerNet/sing-box"
    
    /// GitHub API URL for releases
    static let singBoxReleasesURL = "https://api.github.com/repos/SagerNet/sing-box/releases"
    
    // MARK: - Profile Defaults
    
    /// Default profile auto-update interval in hours
    static let defaultAutoUpdateInterval = 24
    
    /// Minimum auto-update interval in hours
    static let minAutoUpdateInterval = 1
    
    /// Maximum auto-update interval in hours (1 week)
    static let maxAutoUpdateInterval = 168
    
    // MARK: - Network
    
    /// Default network timeout in seconds
    static let networkTimeout: TimeInterval = 30
    
    /// Latency test timeout in seconds
    static let latencyTestTimeout: TimeInterval = 5
    
    // MARK: - UI
    
    /// Sidebar minimum width
    static let sidebarMinWidth: CGFloat = 180
    
    /// Sidebar ideal width
    static let sidebarIdealWidth: CGFloat = 220
    
    /// Sidebar maximum width
    static let sidebarMaxWidth: CGFloat = 280
    
    // MARK: - Validation
    
    /// Maximum profile name length
    static let maxProfileNameLength = 100
    
    /// Maximum node name length
    static let maxNodeNameLength = 100
    
    /// Maximum rule name length
    static let maxRuleNameLength = 100
    
    /// Valid port range
    static let validPortRange = 1...65535
}

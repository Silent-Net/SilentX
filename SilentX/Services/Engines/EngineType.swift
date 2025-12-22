import Foundation

/// Identifies the proxy engine implementation type
enum EngineType: String, Codable {
    /// Direct sing-box process launch (HTTP/SOCKS only, no TUN)
    case localProcess

    /// System extension with TUN support via NetworkExtension framework
    case networkExtension
    
    /// Privileged helper service for passwordless operation (recommended)
    case privilegedHelper
    
    // MARK: - Display Names (T068)
    
    /// Chinese display name for UI
    var displayName: String {
        switch self {
        case .localProcess:
            return "本地进程模式"
        case .networkExtension:
            return "系统扩展模式"
        case .privilegedHelper:
            return "免密码模式"
        }
    }
    
    /// English display name
    var displayNameEN: String {
        switch self {
        case .localProcess:
            return "Local Process"
        case .networkExtension:
            return "Network Extension"
        case .privilegedHelper:
            return "Privileged Helper"
        }
    }
    
    /// Short description for tooltips
    var shortDescription: String {
        switch self {
        case .localProcess:
            return "Uses sudo to run sing-box directly. Requires password on each operation."
        case .networkExtension:
            return "Uses macOS System Extension for passwordless operation."
        case .privilegedHelper:
            return "Uses a background service for passwordless operation. Recommended for most users."
        }
    }
}

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
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .localProcess:
            return "Local Process Mode"
        case .networkExtension:
            return "System Extension Mode"
        case .privilegedHelper:
            return "Passwordless Mode"
        }
    }
    
    /// Short identifier
    var shortName: String {
        switch self {
        case .localProcess:
            return "Local"
        case .networkExtension:
            return "Extension"
        case .privilegedHelper:
            return "Helper"
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

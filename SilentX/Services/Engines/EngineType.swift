import Foundation

/// Identifies the proxy engine implementation type
enum EngineType: String, Codable {
    /// Direct sing-box process launch (HTTP/SOCKS only, no TUN)
    case localProcess

    /// System extension with TUN support via NetworkExtension framework
    case networkExtension
}

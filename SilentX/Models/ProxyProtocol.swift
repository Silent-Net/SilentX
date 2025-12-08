//
//  ProxyProtocol.swift
//  SilentX
//
//  Proxy protocol type enumeration
//

import Foundation

/// Supported proxy protocols
enum ProxyProtocol: String, Codable, CaseIterable, Identifiable {
    case shadowsocks = "shadowsocks"
    case vmess = "vmess"
    case vless = "vless"
    case trojan = "trojan"
    case hysteria2 = "hysteria2"
    case http = "http"
    case socks5 = "socks5"
    
    var id: String { rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .shadowsocks: return "Shadowsocks"
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .hysteria2: return "Hysteria2"
        case .http: return "HTTP"
        case .socks5: return "SOCKS5"
        }
    }
    
    /// SF Symbol name for the protocol
    var systemImage: String {
        switch self {
        case .shadowsocks: return "shield.lefthalf.filled"
        case .vmess: return "v.circle"
        case .vless: return "v.circle.fill"
        case .trojan: return "lock.shield"
        case .hysteria2: return "bolt.shield"
        case .http: return "globe"
        case .socks5: return "network"
        }
    }
    
    /// Whether the protocol requires encryption credentials
    var requiresCredentials: Bool {
        switch self {
        case .shadowsocks, .vmess, .vless, .trojan, .hysteria2:
            return true
        case .http, .socks5:
            return false
        }
    }
}

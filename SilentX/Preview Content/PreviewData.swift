//
//  PreviewData.swift
//  SilentX
//
//  Sample data for SwiftUI previews
//

import Foundation
import SwiftData

/// Container for preview sample data
enum PreviewData {
    
    // Preview port - not used in production, just for SwiftUI previews
    static let previewPort = 7890
    
    // MARK: - Profiles
    
    static let localProfile = Profile(
        name: "Home Network",
        type: .local,
        configurationJSON: sampleConfigJSON
    )
    
    static let remoteProfile: Profile = {
        let profile = Profile(
            name: "Work VPN",
            type: .remote,
            configurationJSON: sampleConfigJSON,
            remoteURL: "https://example.com/subscription/config.json"
        )
        profile.lastUpdated = Date().addingTimeInterval(-3600)
        return profile
    }()
    
    static let icloudProfile: Profile = {
        let profile = Profile(
            name: "Synced Profile",
            type: .icloud,
            configurationJSON: sampleConfigJSON
        )
        profile.lastUpdated = Date().addingTimeInterval(-86400)
        return profile
    }()
    
    static let profiles: [Profile] = [localProfile, remoteProfile, icloudProfile]
    
    // MARK: - Proxy Nodes
    
    static let shadowsocksNode: ProxyNode = {
        let node = ProxyNode(
            name: "SS Tokyo",
            serverAddress: "jp1.example.com",
            port: 8388,
            protocolType: .shadowsocks
        )
        try? node.setCredentials([
            "password": "secret-password",
            "method": "aes-256-gcm"
        ])
        return node
    }()
    
    static let vmessNode: ProxyNode = {
        let node = ProxyNode(
            name: "VMess Singapore",
            serverAddress: "sg1.example.com",
            port: 443,
            protocolType: .vmess
        )
        try? node.setCredentials([
            "uuid": "550e8400-e29b-41d4-a716-446655440000",
            "security": "auto",
            "tls": true,
            "sni": "sg1.example.com"
        ])
        return node
    }()
    
    static let trojanNode: ProxyNode = {
        let node = ProxyNode(
            name: "Trojan Hong Kong",
            serverAddress: "hk1.example.com",
            port: 443,
            protocolType: .trojan
        )
        try? node.setCredentials([
            "password": "trojan-password",
            "tls": true
        ])
        return node
    }()
    
    static let hysteria2Node: ProxyNode = {
        let node = ProxyNode(
            name: "Hysteria2 US",
            serverAddress: "us1.example.com",
            port: 443,
            protocolType: .hysteria2
        )
        try? node.setCredentials([
            "password": "hy2-password",
            "upMbps": 100,
            "downMbps": 500
        ])
        return node
    }()
    
    static let nodes: [ProxyNode] = [shadowsocksNode, vmessNode, trojanNode, hysteria2Node]
    
    // MARK: - Routing Rules
    
    static let directCNRule: RoutingRule = {
        let rule = RoutingRule(
            name: "Direct CN Traffic",
            matchType: .geoIP,
            matchValue: "cn",
            action: .direct
        )
        rule.order = 1
        return rule
    }()
    
    static let proxyDomainRule: RoutingRule = {
        let rule = RoutingRule(
            name: "Proxy Google",
            matchType: .domainSuffix,
            matchValue: "google.com",
            action: .proxy
        )
        rule.order = 2
        return rule
    }()
    
    static let blockAdsRule: RoutingRule = {
        let rule = RoutingRule(
            name: "Block Ads",
            matchType: .domain,
            matchValue: "ads.example.com",
            action: .block
        )
        rule.order = 3
        return rule
    }()
    
    static let rules: [RoutingRule] = [directCNRule, proxyDomainRule, blockAdsRule]
    
    // MARK: - Core Versions
    
    static let activeVersion: CoreVersion = {
        let version = CoreVersion(
            version: "1.9.0",
            downloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-darwin-arm64.tar.gz"
        )
        version.downloadDate = Date().addingTimeInterval(-86400 * 7)
        version.isActive = true
        version.localPath = "/Applications/SilentX.app/Contents/Resources/sing-box"
        return version
    }()
    
    static let olderVersion: CoreVersion = {
        let version = CoreVersion(
            version: "1.8.14",
            downloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.8.14/sing-box-1.8.14-darwin-arm64.tar.gz"
        )
        version.downloadDate = Date().addingTimeInterval(-86400 * 30)
        version.localPath = "/Users/xmx/.silentx/cores/1.8.14/sing-box"
        return version
    }()
    
    static let coreVersions: [CoreVersion] = [activeVersion, olderVersion]
    
    // MARK: - Log Entries
    
    static let sampleLogs: [LogEntry] = [
        LogEntry(
            timestamp: Date().addingTimeInterval(-60),
            level: .info,
            category: LogCategory.system,
            message: "SilentX started"
        ),
        LogEntry(
            timestamp: Date().addingTimeInterval(-55),
            level: .info,
            category: LogCategory.core,
            message: "Sing-Box core version 1.9.0"
        ),
        LogEntry(
            timestamp: Date().addingTimeInterval(-50),
            level: .debug,
            category: LogCategory.config,
            message: "Configuration loaded successfully"
        ),
        LogEntry(
            timestamp: Date().addingTimeInterval(-30),
            level: .info,
            category: LogCategory.connection,
            message: "Connected to proxy server"
        ),
        LogEntry(
            timestamp: Date().addingTimeInterval(-10),
            level: .warning,
            category: LogCategory.tun,
            message: "TUN device buffer warning"
        ),
        LogEntry(
            timestamp: Date(),
            level: .error,
            category: LogCategory.proxy,
            message: "Connection to remote server failed"
        )
    ]
    
    // MARK: - Sample JSON Configuration
    
    static let sampleConfigJSON = """
    {
      "log": {
        "level": "info",
        "timestamp": true
      },
      "dns": {
        "servers": [
          {
            "tag": "google",
            "address": "8.8.8.8"
          }
        ]
      },
      "inbounds": [
        {
          "type": "mixed",
          "tag": "mixed-in",
          "listen": "127.0.0.1",
          "listen_port": \(previewPort)
        }
      ],
      "outbounds": [
        {
          "type": "shadowsocks",
          "tag": "proxy",
          "server": "server.example.com",
          "server_port": 8388,
          "method": "aes-256-gcm",
          "password": "password"
        },
        {
          "type": "direct",
          "tag": "direct"
        },
        {
          "type": "block",
          "tag": "block"
        }
      ],
      "route": {
        "rules": [
          {
            "geoip": "cn",
            "outbound": "direct"
          },
          {
            "geosite": "cn",
            "outbound": "direct"
          }
        ],
        "final": "proxy"
      }
    }
    """
    
    // MARK: - Preview Model Container
    
    @MainActor
    static let previewContainer: ModelContainer = {
        let schema = Schema([
            Profile.self,
            ProxyNode.self,
            RoutingRule.self,
            CoreVersion.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Insert sample data
            let context = container.mainContext
            
            for profile in profiles {
                context.insert(profile)
            }
            
            for node in nodes {
                context.insert(node)
            }
            
            for rule in rules {
                context.insert(rule)
            }
            
            for version in coreVersions {
                context.insert(version)
            }
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}

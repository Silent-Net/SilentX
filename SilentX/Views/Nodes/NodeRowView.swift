//
//  NodeRowView.swift
//  SilentX
//
//  Row view for displaying a proxy node in the list
//

import SwiftUI

/// Row view for a single proxy node in the list
struct NodeRowView: View {
    let node: ProxyNode
    
    var body: some View {
        HStack(spacing: 12) {
            // Protocol icon
            protocolIcon
            
            // Node info
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    // Server address
                    Text("\(node.server):\(node.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // TLS indicator
                    if node.tls {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            // Latency indicator
            latencyView
        }
        .padding(.vertical, 4)
    }
    
    private var protocolIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(node.protocolType.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Text(node.protocolType.shortName)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(node.protocolType.color)
        }
    }
    
    @ViewBuilder
    private var latencyView: some View {
        if let latency = node.latency {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(latencyColor(latency))
                        .frame(width: 8, height: 8)
                    Text("\(latency) ms")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(latencyColor(latency))
                }
                
                if let lastTested = node.lastLatencyTest {
                    Text(lastTested.formatted(.relative(presentation: .numeric)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            Text("Not tested")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    private func latencyColor(_ latency: Int) -> Color {
        switch latency {
        case 0..<100:
            return .green
        case 100..<300:
            return .yellow
        case 300..<500:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Protocol Type Extensions (UI-specific)

extension ProxyProtocol {
    var shortName: String {
        switch self {
        case .shadowsocks: return "SS"
        case .vmess: return "VM"
        case .vless: return "VL"
        case .trojan: return "TR"
        case .hysteria2: return "H2"
        case .http: return "HTTP"
        case .socks5: return "S5"
        }
    }
    
    var color: Color {
        switch self {
        case .shadowsocks: return .blue
        case .vmess: return .purple
        case .vless: return .indigo
        case .trojan: return .red
        case .hysteria2: return .orange
        case .http: return .gray
        case .socks5: return .teal
        }
    }
}

#Preview {
    List {
        NodeRowView(node: {
            let node = ProxyNode(
                name: "Hong Kong Server",
                protocolType: .shadowsocks,
                server: "hk.example.com",
                port: 8388
            )
            node.latency = 85
            node.lastLatencyTest = Date().addingTimeInterval(-300)
            node.tls = true
            return node
        }())
        
        NodeRowView(node: {
            let node = ProxyNode(
                name: "US Server",
                protocolType: .vmess,
                server: "us.example.com",
                port: 443
            )
            node.latency = 250
            node.lastLatencyTest = Date().addingTimeInterval(-3600)
            return node
        }())
        
        NodeRowView(node: ProxyNode(
            name: "Japan Server",
            protocolType: .trojan,
            server: "jp.example.com",
            port: 443
        ))
    }
}

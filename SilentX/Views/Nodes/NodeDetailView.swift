//
//  NodeDetailView.swift
//  SilentX
//
//  Detail view for viewing node properties
//

import SwiftUI
import SwiftData

/// Detail view for a single proxy node
struct NodeDetailView: View {
    let node: ProxyNode
    @Environment(\.modelContext) private var modelContext
    
    @State private var showEditSheet = false
    @State private var isTesting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                nodeHeader
                
                Divider()
                
                // Connection details
                connectionSection
                
                Divider()
                
                // Protocol-specific details
                protocolSection
                
                if node.tls {
                    Divider()
                    tlsSection
                }
                
                Divider()
                
                // Latency info
                latencySection
            }
            .padding()
        }
        .navigationTitle(node.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditNodeSheet(node: node)
        }
    }
    
    private var nodeHeader: some View {
        HStack(spacing: 16) {
            // Protocol badge
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(node.protocolType.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 2) {
                    Text(node.protocolType.shortName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(node.protocolType.color)
                    Text(node.protocolType.displayName)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(node.server):\(node.port)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Test button
            Button {
                testLatency()
            } label: {
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("Test", systemImage: "speedometer")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isTesting)
        }
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)
            
            LabeledContent("Server") {
                Text(node.server)
                    .textSelection(.enabled)
            }
            
            LabeledContent("Port") {
                Text("\(node.port)")
            }
            
            LabeledContent("Protocol") {
                Text(node.protocolType.displayName)
            }
        }
    }
    
    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protocol Settings")
                .font(.headline)
            
            switch node.protocolType {
            case .shadowsocks:
                if let method = node.method {
                    LabeledContent("Encryption Method") {
                        Text(method)
                    }
                }
                LabeledContent("Password") {
                    Text("••••••••")
                }
                
            case .vmess, .vless:
                if let uuid = node.uuid {
                    LabeledContent("UUID") {
                        Text(uuid.prefix(8) + "...")
                            .textSelection(.enabled)
                    }
                }
                if let alterId = node.alterId {
                    LabeledContent("Alter ID") {
                        Text("\(alterId)")
                    }
                }
                if let security = node.security {
                    LabeledContent("Security") {
                        Text(security)
                    }
                }
                
            case .trojan:
                LabeledContent("Password") {
                    Text("••••••••")
                }
                
            case .hysteria2:
                LabeledContent("Password") {
                    Text("••••••••")
                }
                if let up = node.upMbps {
                    LabeledContent("Upload Speed") {
                        Text("\(up) Mbps")
                    }
                }
                if let down = node.downMbps {
                    LabeledContent("Download Speed") {
                        Text("\(down) Mbps")
                    }
                }
                
            case .http, .socks5:
                if let username = node.username {
                    LabeledContent("Username") {
                        Text(username)
                    }
                }
                if node.password != nil {
                    LabeledContent("Password") {
                        Text("••••••••")
                    }
                }
            }
        }
    }
    
    private var tlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TLS Settings")
                .font(.headline)
            
            LabeledContent("TLS") {
                Text("Enabled")
                    .foregroundStyle(.green)
            }
            
            if let sni = node.sni {
                LabeledContent("SNI") {
                    Text(sni)
                }
            }
            
            LabeledContent("Certificate Verification") {
                Text(node.skipCertVerify ? "Disabled" : "Enabled")
                    .foregroundStyle(node.skipCertVerify ? .orange : .green)
            }
        }
    }
    
    private var latencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)
            
            if let latency = node.latency {
                LabeledContent("Latency") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(latencyColor(latency))
                            .frame(width: 8, height: 8)
                        Text("\(latency) ms")
                            .foregroundStyle(latencyColor(latency))
                    }
                }
            } else {
                LabeledContent("Latency") {
                    Text("Not tested")
                        .foregroundStyle(.secondary)
                }
            }
            
            if let lastTested = node.lastLatencyTest {
                LabeledContent("Last Tested") {
                    Text(lastTested.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }
    
    private func latencyColor(_ latency: Int) -> Color {
        switch latency {
        case 0..<100: return .green
        case 100..<300: return .yellow
        case 300..<500: return .orange
        default: return .red
        }
    }
    
    private func testLatency() {
        isTesting = true
        
        Task { @MainActor in
            // Mock latency test
            try? await Task.sleep(nanoseconds: 500_000_000)
            node.latency = Int.random(in: 50...500)
            node.lastLatencyTest = Date()
            try? modelContext.save()
            isTesting = false
        }
    }
}

#Preview {
    NavigationStack {
        NodeDetailView(node: {
            let node = ProxyNode(
                name: "Test Server",
                protocolType: .vmess,
                server: "test.example.com",
                port: 443
            )
            node.uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            node.security = "auto"
            node.tls = true
            node.sni = "test.example.com"
            node.latency = 150
            node.lastLatencyTest = Date()
            return node
        }())
    }
    .modelContainer(for: ProxyNode.self, inMemory: true)
}

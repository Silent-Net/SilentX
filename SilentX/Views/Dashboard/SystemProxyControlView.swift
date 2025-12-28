//
//  SystemProxyControlView.swift
//  SilentX
//
//  System proxy controls for HTTP/SOCKS proxy settings
//

import SwiftUI

/// System proxy control view - single toggle for system proxy with port display
struct SystemProxyControlView: View {
    @EnvironmentObject var connectionService: ConnectionService
    
    @State private var systemProxyEnabled = false
    @State private var isApplying = false
    
    private var mixedPort: Int? {
        connectionService.httpPort ?? connectionService.socksPort
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "network")
                .font(.title2)
                .foregroundStyle(systemProxyEnabled ? .blue : .secondary)
                .frame(width: 32, height: 32)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("System Proxy")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let port = mixedPort, port > 0 {
                    Text("127.0.0.1:" + String(port))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $systemProxyEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(mixedPort == nil || mixedPort == 0 || isApplying)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .onChange(of: systemProxyEnabled) { _, enabled in
            Task {
                await applySystemProxy(enabled)
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        systemProxyEnabled = connectionService.isSystemHttpProxyEnabled || connectionService.isSystemSocksProxyEnabled
    }
    
    private func applySystemProxy(_ enabled: Bool) async {
        isApplying = true
        defer { isApplying = false }
        
        do {
            try await connectionService.setSystemProxy(
                httpEnabled: enabled,
                socksEnabled: enabled
            )
        } catch {
            loadCurrentSettings()
        }
    }
}

#Preview {
    SystemProxyControlView()
        .environmentObject(ConnectionService())
        .padding()
        .frame(width: 400)
}

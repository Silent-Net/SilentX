//
//  ConnectionStatusView.swift
//  SilentX
//
//  Connection status indicator component
//

import SwiftUI

/// Visual indicator for connection status
struct ConnectionStatusView: View {
    let status: ConnectionStatus
    @State private var showErrorDetails = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Animated status indicator
                StatusIndicator(status: status)
                    .accessibilityIdentifier("ConnectionStatusIndicator")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.displayText)
                        .font(.headline)
                    
                    if let duration = status.connectedDuration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Show details button for errors
                if case .error = status {
                    Button(action: { showErrorDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(status.color.opacity(0.3), lineWidth: 1)
            )
            
            // Error recovery guidance
            if case .error(let proxyError) = status, showErrorDetails {
                let message = proxyError.localizedDescription
                VStack(alignment: .leading, spacing: 8) {
                    Text("What to try:")
                        .font(.caption.bold())

                    if message.contains("proxy") || message.contains("permission") {
                        Text("• Check system proxy permissions in System Settings > Network")
                            .font(.caption)
                        Text("• Try running SilentX with administrator privileges")
                            .font(.caption)
                    } else if message.contains("Core") || message.contains("core") || message.contains("binary") {
                        Text("• Download a Sing-Box core version in Settings")
                            .font(.caption)
                        Text("• Verify the core binary is executable")
                            .font(.caption)
                    } else {
                        Text("• Check your internet connection")
                            .font(.caption)
                        Text("• Verify profile configuration is valid")
                            .font(.caption)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "Connected for %d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "Connected for %02d:%02d", minutes, seconds)
        }
    }
}

/// Animated circle indicator
struct StatusIndicator: View {
    let status: ConnectionStatus
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(status.color.opacity(0.2))
                .frame(width: 44, height: 44)
            
            // Main indicator
            Circle()
                .fill(status.color)
                .frame(width: 20, height: 20)
                .scaleEffect(isAnimating && status.isTransitioning ? 0.8 : 1.0)
                .animation(
                    status.isTransitioning 
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: isAnimating
                )
            
            // Pulse effect for connected state
            if status.isConnected {
                Circle()
                    .stroke(status.color.opacity(0.4), lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("Disconnected") {
    ConnectionStatusView(status: .disconnected)
        .padding()
}

#Preview("Connecting") {
    ConnectionStatusView(status: .connecting)
        .padding()
}

#Preview("Connected") {
    let info = ConnectionInfo(
        engineType: .localProcess,
        startTime: Date().addingTimeInterval(-3665),
        configName: "Preview",
        listenPorts: [2080]
    )
    return ConnectionStatusView(status: .connected(info))
        .padding()
}

#Preview("Error") {
    ConnectionStatusView(status: .error(.coreStartFailed("Connection refused")))
        .padding()
}

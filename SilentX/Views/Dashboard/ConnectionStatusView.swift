//
//  ConnectionStatusView.swift
//  SilentX
//
//  Connection status indicator component
//  T069-T074: Enhanced status display with engine type and duration
//

import SwiftUI
import Combine

/// Visual indicator for connection status
struct ConnectionStatusView: View {
    let status: ConnectionStatus
    /// T072: Callback for reconnect action when crash detected
    var onReconnect: (() -> Void)?
    
    @State private var showErrorDetails = false
    @State private var currentTime = Date()
    
    // Timer for live duration updates (T074)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Animated status indicator with color coding (T072)
                StatusIndicator(status: status)
                    .accessibilityIdentifier("ConnectionStatusIndicator")
                
                VStack(alignment: .leading, spacing: 2) {
                    // Status text
                    Text(status.displayText)
                        .font(.headline)
                    
                    // T069: Show engine type when connected
                    if case .connected(let info) = status {
                        HStack(spacing: 6) {
                            // Engine type badge
                            Text(info.engineType.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(info.engineType == .networkExtension 
                                              ? Color.blue.opacity(0.2) 
                                              : Color.orange.opacity(0.2))
                                )
                            
                            // T070: Connection duration
                            Text(info.formattedDuration(to: currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // T071: User-friendly error messages
                    if case .error(let error) = status {
                        Text(error.userMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // T072: Reconnect button when crash detected
                if case .error = status, let reconnect = onReconnect {
                    Button(action: reconnect) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reconnect")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                // Show details button for errors
                if case .error = status {
                    Button(action: { showErrorDetails.toggle() }) {
                        Image(systemName: showErrorDetails ? "chevron.up.circle.fill" : "info.circle")
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
            
            // T073: Suggested action text for recoverable errors
            if case .error(let proxyError) = status, showErrorDetails {
                ErrorRecoveryView(error: proxyError)
            }
        }
        .onReceive(timer) { _ in
            // T074: Update duration every second when connected
            if case .connected = status {
                currentTime = Date()
            }
        }
    }
}

/// Error recovery guidance view
/// T073: Provides suggested actions for different error types
private struct ErrorRecoveryView: View {
    let error: ProxyError
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Technical details (expandable)
            if !error.localizedDescription.isEmpty {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            
            Text("Suggested Actions:")
                .font(.caption.bold())
            
            ForEach(suggestedActions, id: \.self) { action in
                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                    Text(action)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var suggestedActions: [String] {
        switch error {
        case .extensionNotInstalled:
            return [
                "Go to Settings → Proxy Mode to install system extension"
            ]
        case .extensionNotApproved:
            return [
                "Go to System Settings → Privacy & Security to approve extension"
            ]
        case .extensionLoadFailed:
            return [
                "Try reinstalling the system extension"
            ]
        case .tunnelStartFailed:
            return [
                "Check VPN configuration is correct",
                "Check network connectivity"
            ]
        case .coreNotFound:
            return [
                "Go to Settings → Core Versions to download Sing-Box"
            ]
        case .coreStartFailed:
            return [
                "Check if configuration file is valid",
                "View logs for detailed error information",
                "Try using a different configuration file"
            ]
        case .configNotFound, .configInvalid:
            return [
                "Check if configuration file exists",
                "Verify JSON format is correct",
                "Try re-importing the configuration"
            ]
        case .portConflict(let ports):
            return [
                "Ports \(ports.map(String.init).joined(separator: ", ")) are in use",
                "Close the program using these ports and retry",
                "Or modify configuration to use different ports"
            ]
        case .permissionDenied:
            return [
                "Check application permissions",
                "Try running as administrator"
            ]
        case .timeout:
            return [
                "Check network connection",
                "Try reconnecting",
                "View logs for more information"
            ]
        case .unknown:
            return [
                "Try reconnecting",
                "Check logs for more information"
            ]
        }
    }
}

/// Animated circle indicator
/// T072: Color-coded status indicator (green/red/gray/orange)
struct StatusIndicator: View {
    let status: ConnectionStatus
    
    // Initialize to true to prevent animation on first appear
    // This avoids the "fly in from corner" bug caused by implicit animation leak
    @State private var isAnimating = true
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(status.color.opacity(0.2))
                .frame(width: 44, height: 44)
            
            // Main indicator - use explicit animation scoped to isAnimating only
            Circle()
                .fill(status.color)
                .frame(width: 20, height: 20)
                .scaleEffect(isAnimating && status.isTransitioning ? 0.8 : 1.0)
                .animation(
                    status.isTransitioning 
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: status.isTransitioning
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
        // No onAppear needed since isAnimating starts as true
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

#Preview("Connected - LocalProcess") {
    let info = ConnectionInfo(
        engineType: .localProcess,
        startTime: Date().addingTimeInterval(-3665),
        configName: "Preview",
        listenPorts: [2080]
    )
    return ConnectionStatusView(status: .connected(info))
        .padding()
}

#Preview("Connected - NetworkExtension") {
    let info = ConnectionInfo(
        engineType: .networkExtension,
        startTime: Date().addingTimeInterval(-125),
        configName: "Preview VPN",
        listenPorts: []
    )
    return ConnectionStatusView(status: .connected(info))
        .padding()
}

#Preview("Error - Extension Not Installed") {
    ConnectionStatusView(status: .error(.extensionNotInstalled))
        .padding()
}

#Preview("Error - Core Not Found") {
    ConnectionStatusView(status: .error(.coreNotFound))
        .padding()
}

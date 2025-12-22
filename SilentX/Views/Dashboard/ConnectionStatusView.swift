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
                            Text("重连")
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
            
            Text("建议操作 / Suggested Actions:")
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
                "前往 设置 → 代理模式 安装系统扩展",
                "Go to Settings → Proxy Mode to install system extension"
            ]
        case .extensionNotApproved:
            return [
                "前往 系统设置 → 隐私与安全性 批准扩展",
                "Go to System Settings → Privacy & Security to approve"
            ]
        case .extensionLoadFailed:
            return [
                "尝试重新安装系统扩展",
                "Try reinstalling the system extension"
            ]
        case .tunnelStartFailed:
            return [
                "检查 VPN 配置是否正确",
                "Check network connectivity",
                "查看系统设置中的 VPN 状态"
            ]
        case .coreNotFound:
            return [
                "前往 设置 → 内核版本 下载 Sing-Box",
                "Go to Settings → Core Versions to download"
            ]
        case .coreStartFailed:
            return [
                "检查配置文件是否有效",
                "查看日志获取详细错误信息",
                "尝试使用其他配置文件"
            ]
        case .configNotFound, .configInvalid:
            return [
                "检查配置文件是否存在",
                "验证 JSON 格式是否正确",
                "尝试重新导入配置"
            ]
        case .portConflict(let ports):
            return [
                "端口 \(ports.map(String.init).joined(separator: ", ")) 被占用",
                "关闭占用端口的程序后重试",
                "或修改配置使用其他端口"
            ]
        case .permissionDenied:
            return [
                "检查应用程序权限",
                "尝试以管理员身份运行",
                "Check application permissions"
            ]
        case .timeout:
            return [
                "检查网络连接",
                "尝试重新连接",
                "查看日志获取详细信息"
            ]
        case .unknown:
            return [
                "尝试重新连接",
                "检查日志获取更多信息",
                "Try reconnecting"
            ]
        }
    }
}

/// Animated circle indicator
/// T072: Color-coded status indicator (green/red/gray/orange)
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

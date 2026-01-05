//
//  ConnectButton.swift
//  SilentX
//
//  Connect/disconnect button component
//

import SwiftUI

/// Button size variants
enum ConnectButtonSize {
    case regular
    case large
    
    var dimension: CGFloat {
        switch self {
        case .regular: return 120
        case .large: return 150
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .regular: return 32
        case .large: return 40
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .regular: return 8
        case .large: return 12
        }
    }
    
    var font: Font {
        switch self {
        case .regular: return .headline
        case .large: return .title3.weight(.semibold)
        }
    }
}

/// Large connect/disconnect button
struct ConnectButton: View {
    let status: ConnectionStatus
    var size: ConnectButtonSize = .regular
    let action: () async -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            VStack(spacing: size.spacing) {
                Image(systemName: buttonIcon)
                    .font(.system(size: size.iconSize, weight: .medium))
                
                Text(buttonText)
                    .font(size.font)
            }
            .foregroundColor(buttonForegroundColor)
            .frame(width: size.dimension, height: size.dimension)
            .background(buttonBackground)
            .clipShape(Circle())
            .shadow(color: shadowColor, radius: isPressed ? 4 : 8, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(!status.canToggle)
        .opacity(status.canToggle ? 1.0 : 0.6)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var buttonIcon: String {
        switch status {
        case .disconnected, .error:
            return "power"
        case .connecting:
            return "circle.dotted"
        case .connected:
            return "stop.fill"
        case .disconnecting:
            return "circle.dotted"
        }
    }
    
    private var buttonText: String {
        switch status {
        case .disconnected, .error:
            return "Connect"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Disconnect"
        case .disconnecting:
            return "Stopping"
        }
    }
    
    private var buttonForegroundColor: Color {
        switch status {
        case .disconnected, .error:
            return .white
        case .connecting, .disconnecting:
            return .orange
        case .connected:
            return .white
        }
    }
    
    private var buttonBackground: some ShapeStyle {
        switch status {
        case .disconnected, .error:
            return AnyShapeStyle(Color.accentColor.gradient)
        case .connecting, .disconnecting:
            return AnyShapeStyle(Color.orange.opacity(0.2).gradient)
        case .connected:
            return AnyShapeStyle(Color.red.gradient)
        }
    }
    
    private var shadowColor: Color {
        switch status {
        case .disconnected, .error:
            return .accentColor.opacity(0.3)
        case .connecting, .disconnecting:
            return .clear
        case .connected:
            return .red.opacity(0.3)
        }
    }
}

#Preview("Disconnected") {
    ConnectButton(status: .disconnected) {}
        .padding()
}

#Preview("Connecting") {
    ConnectButton(status: .connecting) {}
        .padding()
}

#Preview("Connected") {
    let info = ConnectionInfo(
        engineType: .localProcess,
        startTime: Date(),
        configName: "Preview",
        listenPorts: [PreviewData.previewPort]
    )
    return ConnectButton(status: .connected(info)) {}
        .padding()
}

#Preview("Error") {
    ConnectButton(status: .error(.configNotFound)) {}
        .padding()
}

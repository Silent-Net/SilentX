import Foundation
import SwiftUI

/// Connection status with associated values
enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected(ConnectionInfo)
    case disconnecting
    case error(ProxyError)

    // MARK: - Helper Properties (for UI compatibility)

    /// Human-readable display text
    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .error(let proxyError):
            return "Error: \(proxyError.localizedDescription)"
        }
    }

    /// Short status text
    var shortText: String {
        switch self {
        case .disconnected:
            return "Off"
        case .connecting:
            return "Connecting"
        case .connected:
            return "On"
        case .disconnecting:
            return "Stopping"
        case .error:
            return "Error"
        }
    }

    /// Color associated with the status
    var color: Color {
        switch self {
        case .disconnected:
            return .secondary
        case .connecting, .disconnecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    /// Whether proxy can be toggled in this state
    var canToggle: Bool {
        switch self {
        case .disconnected, .connected, .error:
            return true
        case .connecting, .disconnecting:
            return false
        }
    }

    /// Whether currently connected
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    /// Whether in a transitional state
    var isTransitioning: Bool {
        switch self {
        case .connecting, .disconnecting:
            return true
        default:
            return false
        }
    }

    /// Connected duration if connected
    var connectedDuration: TimeInterval? {
        if case .connected(let info) = self {
            return info.duration
        }
        return nil
    }
}

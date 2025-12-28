import Foundation

/// Categorized errors for proxy engine operations
enum ProxyError: Error, Equatable, LocalizedError {
    case configInvalid(String)
    case configNotFound
    case coreNotFound
    case coreStartFailed(String)
    case portConflict([Int])
    case permissionDenied
    // Network Extension errors (T053-T056)
    case extensionNotInstalled
    case extensionNotApproved
    case extensionLoadFailed(String)
    case tunnelStartFailed(String)
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .configInvalid(let detail):
            return "Configuration error: \(detail)"
        case .configNotFound:
            return "Configuration file not found"
        case .coreNotFound:
            return "Sing-box core not found"
        case .coreStartFailed(let detail):
            return "Core startup failed: \(detail)"
        case .portConflict(let ports):
            return "Port conflict: \(ports.map(String.init).joined(separator: ", "))"
        case .permissionDenied:
            return "Permission denied"
        case .extensionNotInstalled:
            return "System extension not installed"
        case .extensionNotApproved:
            return "System extension not approved"
        case .extensionLoadFailed(let detail):
            return "Failed to load VPN profile: \(detail)"
        case .tunnelStartFailed(let detail):
            return "Tunnel startup failed: \(detail)"
        case .timeout:
            return "Operation timeout"
        case .unknown(let detail):
            return "Unknown error: \(detail)"
        }
    }

    /// Whether this error is recoverable by user action
    var isRecoverable: Bool {
        switch self {
        case .configInvalid, .configNotFound, .coreNotFound, .portConflict,
             .extensionNotInstalled, .extensionNotApproved, .extensionLoadFailed:
            return true
        case .coreStartFailed, .permissionDenied, .tunnelStartFailed, .timeout, .unknown:
            return false
        }
    }

    /// Suggested action for user to take
    var suggestedAction: String? {
        switch self {
        case .configInvalid:
            return "Check configuration file format"
        case .configNotFound:
            return "Select a valid configuration file"
        case .coreNotFound:
            return "Download sing-box core in Settings"
        case .portConflict(let ports):
            return "Close applications using ports: \(ports.map(String.init).joined(separator: ", "))"
        case .extensionNotInstalled:
            return "Install system extension in Settings → Proxy Mode"
        case .extensionNotApproved:
            return "Approve in System Settings → Privacy & Security → Network Extensions"
        case .extensionLoadFailed:
            return "Reinstall VPN profile or restart the app"
        case .tunnelStartFailed:
            return "Check configuration and try again"
        case .permissionDenied:
            return "Restart application or contact administrator"
        case .timeout:
            return "Check network connection and retry"
        case .coreStartFailed, .unknown:
            return "Check logs for details"
        }
    }

    /// User-friendly message for display (same as errorDescription)
    var userMessage: String {
        return errorDescription ?? "Unknown error"
    }
}

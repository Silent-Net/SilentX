import Foundation

/// Categorized errors for proxy engine operations
enum ProxyError: Error, Equatable, LocalizedError {
    case configInvalid(String)
    case configNotFound
    case coreNotFound
    case coreStartFailed(String)
    case portConflict([Int])
    case permissionDenied
    case extensionNotApproved
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
        case .extensionNotApproved:
            return "System extension not approved"
        case .timeout:
            return "Operation timeout"
        case .unknown(let detail):
            return "Unknown error: \(detail)"
        }
    }

    /// Whether this error is recoverable by user action
    var isRecoverable: Bool {
        switch self {
        case .configInvalid, .configNotFound, .coreNotFound, .portConflict, .extensionNotApproved:
            return true
        case .coreStartFailed, .permissionDenied, .timeout, .unknown:
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
        case .extensionNotApproved:
            return "Approve in System Settings → Privacy & Security → Network Extensions"
        case .permissionDenied:
            return "Restart application or contact administrator"
        case .timeout:
            return "Check network connection and retry"
        case .coreStartFailed, .unknown:
            return "Check logs for details"
        }
    }
}

import Foundation
import os

/// Lightweight timing helper for launch/connect/validation metrics.
struct PerformanceMetrics {
    enum Event: String {
        case appLaunch
        case connect
        case configValidation
        case coreSwitch
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SilentX", category: "performance")

    static func time(event: Event, block: () throws -> Void) rethrows {
        let start = DispatchTime.now()
        try block()
        let end = DispatchTime.now()
        let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
        let millis = Double(nanos) / 1_000_000.0
        logger.log("event=\(event.rawValue, privacy: .public) duration_ms=\(millis, privacy: .public)")
    }

    static func log(event: Event, duration: TimeInterval) {
        let millis = duration * 1000
        logger.log("event=\(event.rawValue, privacy: .public) duration_ms=\(millis, privacy: .public)")
    }
}

import Foundation

/// Centralized feature toggles for tests and debugging.
enum FeatureFlags {
    /// Disable window restoration to avoid reopen crashes during tests.
    static let disableWindowRestorationForTests = true

    /// Stub system proxy operations when not permitted.
    static let allowProxyNoopFallback = false
}

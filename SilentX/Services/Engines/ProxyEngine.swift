import Combine
import Foundation

/// Protocol defining the contract for proxy engine implementations.
/// Engines handle starting, stopping, and monitoring proxy connections.
@MainActor
protocol ProxyEngine: AnyObject {

    // MARK: - Properties

    /// Current connection status
    var status: ConnectionStatus { get }

    /// Publisher for status changes (for Combine subscribers)
    var statusPublisher: AnyPublisher<ConnectionStatus, Never> { get }

    /// Type identifier for this engine
    var engineType: EngineType { get }

    // MARK: - Lifecycle Methods

    /// Start the proxy with the given configuration.
    /// - Parameter config: Configuration containing paths and settings
    /// - Throws: ProxyError if startup fails
    /// - Precondition: status must be .disconnected
    func start(config: ProxyConfiguration) async throws

    /// Stop the proxy and cleanup resources.
    /// - Throws: ProxyError if shutdown fails
    /// - Precondition: status must be .connected or .error
    func stop() async throws

    // MARK: - Optional Methods

    /// Validate configuration before starting.
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors, empty if valid
    func validate(config: ProxyConfiguration) async -> [ProxyError]
}

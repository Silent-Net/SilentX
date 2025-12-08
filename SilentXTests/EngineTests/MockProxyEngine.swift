import Combine
import Foundation
@testable import SilentX

/// Mock proxy engine for testing
@MainActor
class MockProxyEngine: ProxyEngine {

    // MARK: - Mock Configuration

    var mockStatus: ConnectionStatus = .disconnected
    var shouldFailStart: Bool = false
    var shouldFailStop: Bool = false
    var startDelay: TimeInterval = 0
    var validationErrors: [ProxyError] = []

    // MARK: - ProxyEngine Protocol

    private let statusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)

    var status: ConnectionStatus {
        statusSubject.value
    }

    var statusPublisher: AnyPublisher<ConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    let engineType: EngineType = .localProcess

    func start(config: ProxyConfiguration) async throws {
        guard status == .disconnected || status == .error(ProxyError.unknown("")) else {
            throw ProxyError.unknown("Cannot start - already connecting or connected")
        }

        statusSubject.send(.connecting)

        if startDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
        }

        if shouldFailStart {
            let error = ProxyError.coreStartFailed("Mock failure")
            statusSubject.send(.error(error))
            throw error
        }

        let info = ConnectionInfo(
            engineType: engineType,
            startTime: Date(),
            configName: "Mock Config",
            listenPorts: [2088]
        )
        statusSubject.send(.connected(info))
    }

    func stop() async throws {
        guard case .connected = status else {
            throw ProxyError.unknown("Cannot stop - not connected")
        }

        statusSubject.send(.disconnecting)

        if shouldFailStop {
            throw ProxyError.unknown("Mock stop failure")
        }

        statusSubject.send(.disconnected)
    }

    func validate(config: ProxyConfiguration) async -> [ProxyError] {
        return validationErrors
    }
}

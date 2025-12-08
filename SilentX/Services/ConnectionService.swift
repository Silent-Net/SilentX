//
//  ConnectionService.swift
//  SilentX
//
//  Connection service for managing proxy connections
//

import Foundation
import Combine
import SwiftData

/// Protocol for connection service
protocol ConnectionServiceProtocol: ObservableObject {
    /// Current connection status
    var status: ConnectionStatus { get }

    /// Starts proxy connection with provided profile
    func connect(profile: Profile) async throws

    /// Stops proxy connection
    func disconnect() async throws

    /// Restarts connection (for config changes)
    func restart() async throws
}

/// Connection service that manages proxy lifecycle using ProxyEngine abstraction
@MainActor
final class ConnectionService: ConnectionServiceProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var status: ConnectionStatus = .disconnected

    // MARK: - Private Properties

    private var lastProfile: Profile?
    private var currentEngine: (any ProxyEngine)?
    private var cancellables = Set<AnyCancellable>()
    private let coreVersionService: any CoreVersionServiceProtocol

    // MARK: - Initialization

    init(
        coreVersionService: (any CoreVersionServiceProtocol)? = nil
    ) {
        self.coreVersionService = coreVersionService ?? {
            let context = ModelContext(SilentXApp.sharedModelContainer)
            return CoreVersionService(modelContext: context)
        }()
    }

    // MARK: - Public Methods

    func connect(profile: Profile) async throws {
        // Don't allow connecting if already connected or in transition
        switch status {
        case .connected, .connecting, .disconnecting:
            throw ConnectionError.invalidState
        default:
            break
        }

        lastProfile = profile

        // T019: Create LocalProcessEngine based on profile preference
        let engine: any ProxyEngine
        switch profile.preferredEngine {
        case .localProcess:
            engine = LocalProcessEngine()
        case .networkExtension:
            // TODO: Phase 4 (US2) - Implement NetworkExtensionEngine
            throw ConnectionError.engineNotAvailable("NetworkExtension engine not yet implemented")
        }
        currentEngine = engine

        // T021: Subscribe to engine status updates
        engine.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                self?.status = newStatus
            }
            .store(in: &cancellables)

        // Prepare configuration
        let configURL = FilePath.profilePath(for: profile.id)
        try profile.configurationJSON.write(to: configURL, atomically: true, encoding: .utf8)

        let coreURL = try resolveCoreBinary()

        let config = ProxyConfiguration(
            profileId: profile.id,
            configPath: configURL,
            corePath: coreURL,
            logLevel: .info
        )

        // T020: Delegate to engine.start()
        try await engine.start(config: config)
    }

    func disconnect() async throws {
        guard let engine = currentEngine else {
            throw ConnectionError.noActiveConnection
        }

        // If already disconnecting, block; if already disconnected, no-op; allow cancel during connecting
        if case .disconnecting = status { throw ConnectionError.invalidState }
        if case .disconnected = status { return }

        // Ensure UI reflects transition even if engine status events are delayed
        status = .disconnecting

        // T020: Delegate to engine.stop()
        try await engine.stop()

        // Fallback: ensure UI reaches disconnected even if engine status missed
        if case .disconnected = status {
            // Already updated by engine
        } else {
            status = .disconnected
        }

        // Cleanup
        currentEngine = nil
        cancellables.removeAll()
    }

    func restart() async throws {
        if case .connected = status {
            try await disconnect()
        }
        if let profile = lastProfile {
            try await connect(profile: profile)
        } else {
            throw ConnectionError.noActiveProfile
        }
    }

    // MARK: - Private Methods

    private func resolveCoreBinary() throws -> URL {
        // Method 1: Try active version from CoreVersionService
        if let active = coreVersionService.activeVersion?.localPath {
            let url = URL(fileURLWithPath: active)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Method 2: Try first cached version from CoreVersionService
        if let firstCached = coreVersionService.cachedVersions.first?.localPath {
            let url = URL(fileURLWithPath: firstCached)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Method 3: Directly scan FilePath.cores directory
        let coresDir = FilePath.cores
        if let contents = try? FileManager.default.contentsOfDirectory(at: coresDir, includingPropertiesForKeys: nil) {
            for versionDir in contents where versionDir.hasDirectoryPath {
                let binaryURL = versionDir.appendingPathComponent("sing-box")
                if FileManager.default.fileExists(atPath: binaryURL.path) {
                    return binaryURL
                }
            }
        }

        // Method 4: Try default version path
        let defaultPath = FilePath.singBoxBinary(for: Constants.defaultSingBoxVersion)
        if FileManager.default.fileExists(atPath: defaultPath.path) {
            return defaultPath
        }

        // Method 5: Direct database query as last resort
        let descriptor = FetchDescriptor<CoreVersion>(
            predicate: #Predicate<CoreVersion> { $0.localPath != nil }
        )
        if let versions = try? SilentXApp.sharedModelContainer.mainContext.fetch(descriptor) {
            // Prefer active version
            if let active = versions.first(where: { $0.isActive }), let path = active.localPath {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            // Try any version
            for version in versions {
                if let path = version.localPath {
                    let url = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        return url
                    }
                }
            }
        }

        throw ConnectionError.coreError(
            "Sing-Box core not found.\nPlease download a core version in Settings."
        )
    }
}

/// Connection errors
enum ConnectionError: LocalizedError {
    case invalidState
    case noActiveProfile
    case noActiveConnection
    case configurationError(String)
    case coreError(String)
    case engineNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "Cannot toggle connection in current state"
        case .noActiveProfile:
            return "No profile selected"
        case .noActiveConnection:
            return "No active connection"
        case .configurationError(let detail):
            return "Configuration error: \(detail)"
        case .coreError(let detail):
            return "Core error: \(detail)"
        case .engineNotAvailable(let detail):
            return "Engine not available: \(detail)"
        }
    }
}

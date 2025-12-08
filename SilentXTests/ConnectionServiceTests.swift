import XCTest
import Combine
@testable import SilentX

/// Unit tests for ConnectionService
/// Covers watchdog, crash handling, and proxy restoration
@MainActor
final class ConnectionServiceTests: XCTestCase {
    
    var service: ConnectionService!

    override func setUpWithError() throws {
        service = ConnectionService()
    }
    
    override func tearDownWithError() throws {
        service = nil
    }
    
    // MARK: - T012: Watchdog and Crash Handling
    
    /// Test that core crash surfaces error and restores proxy
    func testCoreCrashSurfacesErrorAndRestoresProxy() async throws {
        // Given: Connected state
        // TODO: Set up connected state once real implementation exists
        
        // When: Core process crashes
        // TODO: Simulate core crash
        
        // Then: Error is surfaced
        // XCTAssertEqual(service.status, .error("Core process crashed"))
        
        // And: Proxy is restored
        // XCTAssertTrue(mockSystemProxy.restoreCalled)
    }
    
    /// Test that connection service monitors core process
    func testConnectionServiceMonitorsCoreProcess() async throws {
        // Given: Service with monitoring enabled
        
        // When: Connect (would start core process)
        // TODO: Implement once connect is ready
        
        // Then: Watchdog should be active
        // XCTAssertTrue(service.isMonitoringCore)
    }
    
    /// Test that disconnect properly cleans up watchdog
    func testDisconnectCleansUpWatchdog() async throws {
        // Given: Connected with active watchdog
        // TODO: Set up connected state
        
        // When: Disconnect
        // TODO: Call disconnect once implemented
        
        // Then: Watchdog should be stopped
        // XCTAssertFalse(service.isMonitoringCore)
    }
    
    /// Test that proxy restored before core stop
    func testProxyRestoredBeforeCoreStop() async throws {
        // Given: Connected state with proxy enabled
        
        // When: Disconnect
        // TODO: Call disconnect once implemented
        
        // Then: Proxy restore called before core stop
        // Verify call order
        // XCTAssertTrue(mockSystemProxy.restoreCalled)
        // XCTAssertLessThan(mockSystemProxy.restoreCallTime, mockCore.stopCallTime)
    }
}

// MARK: - Mock Services

class MockSystemProxyService: SystemProxyServiceProtocol {
    var enableCalled = false
    var restoreCalled = false
    var enableCallTime: Date?
    var restoreCallTime: Date?
    
    func enableProxy(host: String, port: Int) throws {
        enableCalled = true
        enableCallTime = Date()
    }
    
    func restoreOriginalSettings() throws {
        restoreCalled = true
        restoreCallTime = Date()
    }
}

@MainActor
class MockCoreVersionService: CoreVersionServiceProtocol, ObservableObject {
    @Published var cachedVersions: [CoreVersion] = []
    @Published var activeVersion: CoreVersion?
    @Published var availableReleases: [GitHubRelease] = []
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    
    var stopCallTime: Date?
    
    func fetchAvailableReleases() async throws {
        // No-op for mock
    }
    
    func downloadVersion(_ release: GitHubRelease) async throws {
        // No-op for mock
    }
    
    func downloadFromURL(_ url: URL, versionName: String) async throws {
        // No-op for mock
    }
    
    func setActiveVersion(_ version: CoreVersion) throws {
        activeVersion = version
    }
    
    func deleteVersion(_ version: CoreVersion) throws {
        cachedVersions.removeAll { $0.id == version.id }
    }
    
    func checkForUpdates() async throws -> GitHubRelease? {
        return nil
    }
}

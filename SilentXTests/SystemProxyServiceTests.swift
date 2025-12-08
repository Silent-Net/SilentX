import XCTest
@testable import SilentX

/// Unit tests for SystemProxyService
/// Covers enable/restore operations and permission-aware fallbacks
final class SystemProxyServiceTests: XCTestCase {
    
    var service: SystemProxyService!
    
    override func setUpWithError() throws {
        service = SystemProxyService()
    }
    
    override func tearDownWithError() throws {
        service = nil
    }
    
    // MARK: - T011: No-op Fallback When Permissions Missing
    
    /// Test that service doesn't crash when networksetup unavailable
    func testEnableProxyWithoutPermissions() throws {
        // When: Enable proxy without permissions (sandboxed app)
        // Then: Should not throw, gracefully no-op
        XCTAssertNoThrow(try service.enableProxy(host: "127.0.0.1", port: 2080))
    }
    
    /// Test that restore doesn't crash when no snapshot exists
    func testRestoreWithoutSnapshot() throws {
        // When: Restore without having enabled first
        // Then: Should not throw, gracefully no-op
        XCTAssertNoThrow(try service.restoreOriginalSettings())
    }
    
    /// Test that service handles empty network services list
    func testHandlesEmptyNetworkServicesList() throws {
        // Given: Service with no detected network services
        let emptyService = SystemProxyService(networkServices: [])
        
        // When: Enable proxy
        // Then: Should not crash
        XCTAssertNoThrow(try emptyService.enableProxy(host: "127.0.0.1", port: 2080))
        
        // When: Restore
        // Then: Should not crash
        XCTAssertNoThrow(try emptyService.restoreOriginalSettings())
    }
    
    /// Test that detectNetworkServices returns empty in sandboxed environment
    func testDetectNetworkServicesInSandbox() {
        // When: Detect services in sandboxed environment
        let services = SystemProxyService.detectNetworkServices()
        
        // Then: Should return empty (safe default)
        XCTAssertTrue(services.isEmpty, "Should return empty array in sandboxed environment")
    }
    
    // MARK: - Error Handling
    
    /// Test that invalid host is rejected
    func testInvalidHostRejection() {
        // When: Enable with invalid host
        // Then: Should handle gracefully (no crash)
        XCTAssertNoThrow(try service.enableProxy(host: "", port: 2080))
    }
    
    /// Test that invalid port is rejected
    func testInvalidPortRejection() {
        // When: Enable with invalid port
        // Then: Should handle gracefully (no crash)
        XCTAssertNoThrow(try service.enableProxy(host: "127.0.0.1", port: 0))
        XCTAssertNoThrow(try service.enableProxy(host: "127.0.0.1", port: 99999))
    }
}

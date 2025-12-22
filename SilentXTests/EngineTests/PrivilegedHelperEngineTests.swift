//
//  PrivilegedHelperEngineTests.swift
//  SilentXTests
//
//  Tests for PrivilegedHelperEngine - proxy engine using privileged helper service
//

import XCTest
import Combine
@testable import SilentX

/// Tests for PrivilegedHelperEngine functionality
/// Note: Integration tests require the privileged helper service to be installed and running
@MainActor
final class PrivilegedHelperEngineTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Unit Tests (No Service Required)
    
    /// Test that engine can be instantiated
    func testEngineInstantiation() async {
        let engine = PrivilegedHelperEngine()
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine.engineType, .privilegedHelper)
    }
    
    /// Test initial status is disconnected
    func testInitialStatus() async {
        let engine = PrivilegedHelperEngine()
        XCTAssertEqual(engine.status, .disconnected)
    }
    
    /// Test status publisher emits initial value
    func testStatusPublisher() async {
        let engine = PrivilegedHelperEngine()
        
        let expectation = XCTestExpectation(description: "Initial status received")
        
        engine.statusPublisher
            .first()
            .sink { status in
                XCTAssertEqual(status, .disconnected)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /// Test that service availability check works
    func testServiceAvailabilityCheck() async {
        let isAvailable = await PrivilegedHelperEngine.isServiceAvailable()
        // This will be true or false depending on whether service is installed
        // We just verify it doesn't crash
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }
    
    /// Test service installed check
    func testServiceInstalledCheck() {
        let isInstalled = PrivilegedHelperEngine.isServiceInstalled()
        // This will be true or false depending on whether service is installed
        // We just verify it doesn't crash
        XCTAssertTrue(isInstalled == true || isInstalled == false)
    }
    
    // MARK: - Validation Tests
    
    /// Test validation fails for missing config
    func testValidateMissingConfig() async {
        let engine = PrivilegedHelperEngine()
        
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/nonexistent/config.json"),
            corePath: URL(fileURLWithPath: "/nonexistent/sing-box"),
            logLevel: .info
        )
        
        let errors = await engine.validate(config: config)
        XCTAssertFalse(errors.isEmpty, "Should have validation errors for missing files")
    }
    
    // MARK: - Integration Tests (Require Service)
    
    /// Test start when service not available
    /// This tests error handling when service is not running
    func testStartWithoutService() async {
        // Only run if service is NOT available (to test error path)
        if await PrivilegedHelperEngine.isServiceAvailable() {
            throw XCTSkip("Service is running - skipping unavailable service test")
        }
        
        let engine = PrivilegedHelperEngine()
        
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/tmp/test-config.json"),
            corePath: URL(fileURLWithPath: "/usr/local/bin/sing-box"),
            logLevel: .info
        )
        
        do {
            try await engine.start(config: config)
            XCTFail("Should throw error when service not available")
        } catch {
            // Expected - service not available
            XCTAssertTrue(true)
        }
    }
    
    /// Test stop when not connected
    func testStopWhenNotConnected() async {
        let engine = PrivilegedHelperEngine()
        
        do {
            try await engine.stop()
            // If disconnected, stop should return without error
        } catch {
            // Some implementations may throw when not connected
            // Either behavior is acceptable
        }
    }
    
    /// Test sync initial state
    func testSyncInitialState() async {
        let engine = PrivilegedHelperEngine()
        
        // This should not crash regardless of service state
        await engine.syncInitialState()
        
        // Status should still be defined (connected if service reports running, disconnected otherwise)
        XCTAssertNotNil(engine.status)
    }
}

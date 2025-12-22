//
//  IPCClientTests.swift
//  SilentXTests
//
//  Tests for IPCClient - Unix socket communication with privileged helper service
//

import XCTest
@testable import SilentX

/// Tests for IPCClient functionality
/// Note: Most tests require the privileged helper service to be running
final class IPCClientTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
    }
    
    // MARK: - Unit Tests (No Service Required)
    
    /// Test that IPCClient can be instantiated
    func testClientInstantiation() async {
        let client = await IPCClient()
        XCTAssertNotNil(client)
    }
    
    /// Test service availability check when service is not running
    func testServiceAvailabilityWhenNotRunning() async {
        // When service is not installed, should return false
        // This test is useful for development environments
        let isAvailable = await IPCClient.isServiceAvailable(socketPath: "/tmp/nonexistent/socket.sock")
        XCTAssertFalse(isAvailable, "Should report unavailable for non-existent socket")
    }
    
    // MARK: - Integration Tests (Require Service)
    
    /// Test ping command
    /// Requires: Service must be running
    func testPing() async throws {
        let client = await IPCClient()
        
        do {
            let pong = try await client.ping()
            XCTAssertEqual(pong, "pong", "Ping should return pong")
        } catch let error as IPCClientError {
            if error.isServiceUnavailable {
                throw XCTSkip("Service not running - skipping integration test")
            }
            throw error
        }
    }
    
    /// Test version command
    /// Requires: Service must be running
    func testVersion() async throws {
        let client = await IPCClient()
        
        do {
            let version = try await client.version()
            XCTAssertFalse(version.version.isEmpty, "Version should not be empty")
        } catch let error as IPCClientError {
            if error.isServiceUnavailable {
                throw XCTSkip("Service not running - skipping integration test")
            }
            throw error
        }
    }
    
    /// Test status command
    /// Requires: Service must be running
    func testStatus() async throws {
        let client = await IPCClient()
        
        do {
            let status = try await client.status()
            // Status should always return, even when core is not running
            XCTAssertNotNil(status)
            // isRunning can be true or false depending on core state
        } catch let error as IPCClientError {
            if error.isServiceUnavailable {
                throw XCTSkip("Service not running - skipping integration test")
            }
            throw error
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// Test that timeout is properly handled
    func testTimeout() async throws {
        // Create client with very short timeout
        let client = await IPCClient(socketPath: "/tmp/silentx/silentx-service.sock", timeout: 0.001)
        
        do {
            _ = try await client.ping()
            // If service is not running, we expect connection error not timeout
        } catch let error as IPCClientError {
            // Either connection failed or timeout - both are acceptable
            XCTAssertTrue(
                error.isServiceUnavailable || error.localizedDescription.contains("timeout"),
                "Expected connection or timeout error"
            )
        }
    }
}

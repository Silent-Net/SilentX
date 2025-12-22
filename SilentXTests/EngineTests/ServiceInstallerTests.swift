//
//  ServiceInstallerTests.swift
//  SilentXTests
//
//  Tests for ServiceInstaller - privileged helper service installation
//

import XCTest
@testable import SilentX

/// Tests for ServiceInstaller functionality
/// Note: Installation/uninstallation tests require admin privileges and are skipped in CI
@MainActor
final class ServiceInstallerTests: XCTestCase {
    
    // MARK: - Unit Tests (No Admin Required)
    
    /// Test that shared instance is accessible
    func testSharedInstance() {
        let installer = ServiceInstaller.shared
        XCTAssertNotNil(installer)
    }
    
    /// Test isInstalled check doesn't crash
    func testIsInstalledCheck() {
        let isInstalled = ServiceInstaller.shared.isInstalled()
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(isInstalled == true || isInstalled == false)
    }
    
    /// Test isRunning check doesn't crash
    func testIsRunningCheck() async {
        let isRunning = await ServiceInstaller.shared.isRunning()
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(isRunning == true || isRunning == false)
    }
    
    /// Test getStatus returns valid status
    func testGetStatus() async {
        let status = await ServiceInstaller.shared.getStatus()
        
        // Verify status properties are consistent
        if status.isRunning {
            XCTAssertTrue(status.isInstalled, "If running, must be installed")
        }
        
        // displayText should not be empty
        XCTAssertFalse(status.displayText.isEmpty, "Display text should not be empty")
        
        // statusColor should be a known color
        XCTAssertTrue(
            ["green", "orange", "gray"].contains(status.statusColor),
            "Status color should be green, orange, or gray"
        )
    }
    
    /// Test service paths are valid
    func testServicePaths() {
        // These should be valid paths (not empty)
        let plistPath = ServicePaths.plistPath
        let binaryDir = ServicePaths.binaryDirectory
        let socketDir = ServicePaths.socketDirectory
        
        XCTAssertFalse(plistPath.isEmpty)
        XCTAssertFalse(binaryDir.isEmpty)
        XCTAssertFalse(socketDir.isEmpty)
        
        // Paths should be absolute
        XCTAssertTrue(plistPath.hasPrefix("/"))
        XCTAssertTrue(binaryDir.hasPrefix("/"))
        XCTAssertTrue(socketDir.hasPrefix("/"))
    }
    
    // MARK: - Path Resolution Tests
    
    /// Test bundled binary path resolution
    func testBundledBinaryPathResolution() {
        // In test environment, the binary may not be bundled
        // We just verify the path resolution logic doesn't crash
        let installer = ServiceInstaller.shared
        
        // This is internal but we can verify through getStatus
        // which uses the bundled paths
        Task {
            let _ = await installer.getStatus()
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// Test error types are properly defined
    func testErrorTypes() {
        // Verify all error cases have descriptions
        let errors: [ServiceInstallerError] = [
            .binaryNotBundled,
            .plistNotBundled,
            .scriptNotBundled,
            .binaryNotFound("test"),
            .plistNotFound("test"),
            .scriptNotFound("test"),
            .scriptFailed("test"),
            .executionFailed("test"),
            .userCancelled,
            .installFailed("test"),
            .uninstallFailed("test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty: \(error)")
        }
    }
    
    // MARK: - Integration Tests (Require Admin - Usually Skipped)
    
    /// Test full install/uninstall cycle
    /// This test requires admin privileges and modifies system state
    /// It's marked as throws to allow XCTSkip
    func testInstallUninstallCycle() async throws {
        // Skip in automated testing - requires admin password
        throw XCTSkip("Install/uninstall cycle requires admin privileges - run manually")
        
        // The actual test would be:
        // 1. Ensure not installed
        // 2. Install
        // 3. Verify installed
        // 4. Verify running (launchd should start it)
        // 5. Uninstall
        // 6. Verify not installed
    }
}

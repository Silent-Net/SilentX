import XCTest

/// Tests for US1: Connect to Proxy Server
/// Covers connect/disconnect flow, proxy enable/restore, and error handling
final class ConnectFlowTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = TestHarness.launchApp(
            environment: ["UI_TESTING": "1"],
            arguments: ["--enable-test-profile"]
        )
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - T009: Happy Path Tests
    
    /// AS1.1: Given valid profile, when click Connect, then connection establishes within 5s and status turns green
    func testConnectHappyPath() throws {
        // Given: App launched with test profile
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
        
        // Navigate to dashboard if needed
        let dashboard = app.buttons["Dashboard"]
        if dashboard.exists {
            dashboard.tap()
        }
        
        // Verify profile selector shows a profile
        let profileSelector = app.popUpButtons["ProfileSelector"]
        XCTAssertTrue(profileSelector.waitForExistence(timeout: 2))
        
        // When: Click Connect
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.exists)
        XCTAssertTrue(connectButton.isEnabled)
        connectButton.tap()
        
        // Then: Connection establishes within 5s
        let connectedStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Connected'")).firstMatch
        XCTAssertTrue(connectedStatus.waitForExistence(timeout: 5), "Connection should establish within 5 seconds")
        
        // Status indicator should be green/connected
        let statusIndicator = app.otherElements["ConnectionStatusIndicator"]
        XCTAssertTrue(statusIndicator.exists)
    }
    
    /// AS1.2: Given connected state, when click Disconnect, then connection terminates and traffic goes direct
    func testDisconnectHappyPath() throws {
        // Given: Connected state (run connect first)
        try testConnectHappyPath()
        
        // When: Click Disconnect
        let disconnectButton = app.buttons["Disconnect"]
        XCTAssertTrue(disconnectButton.waitForExistence(timeout: 2))
        XCTAssertTrue(disconnectButton.isEnabled)
        disconnectButton.tap()
        
        // Then: Status shows disconnected
        let disconnectedStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Disconnected'")).firstMatch
        XCTAssertTrue(disconnectedStatus.waitForExistence(timeout: 3), "Should disconnect within 3 seconds")
        
        // Connect button should be available again
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 2))
        XCTAssertTrue(connectButton.isEnabled)
    }
    
    /// AS1.3: Given first launch with no profiles, then welcome guidance is shown
    func testFirstLaunchNoProfiles() throws {
        // Launch app with no profiles
        app.terminate()
        app = TestHarness.launchApp(
            environment: ["UI_TESTING": "1"],
            arguments: ["--no-profiles"]
        )
        
        // Then: Welcome or empty state guidance shown
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'import' OR label CONTAINS 'create'")).firstMatch
        XCTAssertTrue(emptyStateMessage.waitForExistence(timeout: 3), "Should show guidance for importing profiles")
        
        // Import button should be available
        let importButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Import'")).firstMatch
        XCTAssertTrue(importButton.exists)
    }
    
    // MARK: - T010: Proxy Enable Failure Tests
    
    /// Test that proxy enable failure shows error and rolls back
    func testProxyEnableFailureRollback() throws {
        // Given: App with test profile and simulated proxy failure
        app.terminate()
        app = TestHarness.launchApp(
            environment: ["UI_TESTING": "1", "SIMULATE_PROXY_FAILURE": "1"],
            arguments: ["--enable-test-profile"]
        )
        
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 2))
        
        // When: Attempt to connect with proxy failure
        connectButton.tap()
        
        // Then: Error message shown
        let errorAlert = app.alerts.firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5), "Error alert should appear")
        
        let errorMessage = errorAlert.staticTexts.element(boundBy: 1) // First is title, second is message
        XCTAssertTrue(errorMessage.label.contains("proxy") || errorMessage.label.contains("permission"),
                     "Error should mention proxy or permission issue")
        
        // Dismiss alert
        errorAlert.buttons["OK"].tap()
        
        // Connect button should still be enabled (not stuck in connecting state)
        XCTAssertTrue(connectButton.isEnabled, "Should rollback to disconnected state")
        
        // Status should show disconnected or error
        let statusText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Disconnected' OR label CONTAINS 'Error'")).firstMatch
        XCTAssertTrue(statusText.exists)
    }
    
    /// Test graceful fallback when proxy permissions denied
    func testProxyPermissionDeniedFallback() throws {
        // Given: No proxy permissions
        app.terminate()
        app = TestHarness.launchApp(
            environment: ["UI_TESTING": "1", "NO_PROXY_PERMISSIONS": "1"],
            arguments: ["--enable-test-profile"]
        )
        
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 2))
        
        // When: Connect without permissions
        connectButton.tap()
        
        // Then: Should connect in fallback mode (no system proxy)
        // Or show permission prompt
        let permissionAlert = app.alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 2) {
            // Permission prompt shown
            XCTAssertTrue(permissionAlert.staticTexts.element(boundBy: 1).label.contains("permission") ||
                         permissionAlert.staticTexts.element(boundBy: 1).label.contains("admin"))
        } else {
            // Fallback mode - connected without system proxy
            let connectedStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Connected'")).firstMatch
            XCTAssertTrue(connectedStatus.waitForExistence(timeout: 5))
        }
    }
}

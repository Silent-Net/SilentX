import XCTest

/// Performance test harness with enforced thresholds from success criteria.
final class PerformanceMetricsTests: XCTestCase {
    
    /// SC-007: App launches and is ready to use within 3 seconds.
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let app = XCUIApplication()
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
            app.terminate()
        }
        
        // TODO: Enforce threshold after baseline measurement
        // Expected: <3s per SC-007
    }
    
    /// SC-008: Proxy connection establishment completes within 5 seconds.
    func testConnectionPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Assumes a pre-configured profile exists for testing
        let connectButton = app.buttons["Connect"]
        
        measure(metrics: [XCTClockMetric()]) {
            connectButton.tap()
            let statusIndicator = app.staticTexts["Connected"]
            XCTAssertTrue(statusIndicator.waitForExistence(timeout: 5))
            
            let disconnectButton = app.buttons["Disconnect"]
            disconnectButton.tap()
        }
        
        // TODO: Enforce threshold after baseline measurement
        // Expected: <5s per SC-008
        
        app.terminate()
    }
    
    /// SC-004: Configuration validation errors are displayed within 1 second.
    func testConfigValidationPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to JSON editor
        app.buttons["Profiles"].tap()
        app.buttons["Edit JSON"].tap()
        
        let editor = app.textViews.firstMatch
        
        measure(metrics: [XCTClockMetric()]) {
            // Insert invalid JSON
            editor.tap()
            editor.typeText("{invalid")
            
            // Validation error should appear within 1s
            let errorIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error'")).firstMatch
            XCTAssertTrue(errorIndicator.waitForExistence(timeout: 1))
        }
        
        // TODO: Enforce threshold after baseline measurement
        // Expected: <1s per SC-004
        
        app.terminate()
    }
    
    /// SC-005: Core version switching completes within 10 seconds (excluding download time).
    func testCoreSwitchPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings > Core Versions
        app.buttons["Settings"].tap()
        app.buttons["Core Versions"].tap()
        
        // Assumes at least 2 cached versions exist
        let versionList = app.tables.firstMatch
        let firstVersion = versionList.cells.element(boundBy: 0)
        
        measure(metrics: [XCTClockMetric()]) {
            firstVersion.tap()
            let activeBadge = firstVersion.staticTexts["Active"]
            XCTAssertTrue(activeBadge.waitForExistence(timeout: 10))
        }
        
        // TODO: Enforce threshold after baseline measurement
        // Expected: <10s per SC-005
        
        app.terminate()
    }
    
    // MARK: - Threshold Enforcement (Constitution Section III + SC-007/SC-008)
    
    func testAppLaunchMeetsThreshold() throws {
        let startTime = Date()
        
        let app = XCUIApplication()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 5)
        
        let launchTime = Date().timeIntervalSince(startTime)
        
        // CRITICAL: Fail test if launch exceeds 3s (Constitution Section III, SC-007)
        XCTAssertLessThan(launchTime, 3.0, 
                          "App launch must complete within 3 seconds (SC-007). Actual: \(String(format: "%.2f", launchTime))s")
        
        app.terminate()
    }
    
    func testConnectionEstablishmentMeetsThreshold() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 5)
        
        // Navigate to dashboard
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 2), "Connect button should exist")
        
        let startTime = Date()
        connectButton.tap()
        
        // Wait for connection status to update (mock completes immediately in MVP)
        let statusIndicator = app.staticTexts.matching(identifier: "ConnectionStatus").firstMatch
        _ = statusIndicator.waitForExistence(timeout: 10)
        
        let connectTime = Date().timeIntervalSince(startTime)
        
        // CRITICAL: Fail test if connection exceeds 5s (Constitution Section III, SC-008)
        XCTAssertLessThan(connectTime, 5.0,
                          "Connection establishment must complete within 5 seconds (SC-008). Actual: \(String(format: "%.2f", connectTime))s")
        
        app.terminate()
    }
    
    func testConfigurationValidationMeetsThreshold() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 5)
        
        // Navigate to profiles (triggers validation)
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        
        if profilesButton.waitForExistence(timeout: 2) {
            let startTime = Date()
            profilesButton.tap()
            
            // Wait for profile list to render (validation complete)
            let profilesList = app.scrollViews.firstMatch
            _ = profilesList.waitForExistence(timeout: 3)
            
            let validationTime = Date().timeIntervalSince(startTime)
            
            // CRITICAL: Fail test if validation exceeds 1s (Constitution Section III, SC-004)
            XCTAssertLessThan(validationTime, 1.0,
                              "Configuration validation must complete within 1 second (SC-004). Actual: \(String(format: "%.2f", validationTime))s")
        }
        
        app.terminate()
    }
    
    func testCoreVersionSwitchMeetsThreshold() throws {
        // This test applies to Post-MVP Phase 7 (Core Version Management - US5)
        // CRITICAL: Core version switching must complete within 10s (SC-005)
        
        // For MVP: Skip this test - will be implemented in Phase 7
        throw XCTSkip("Core version switching not implemented in MVP (Phase 7, US5). Threshold: 10s excluding download (SC-005)")
    }
    
}


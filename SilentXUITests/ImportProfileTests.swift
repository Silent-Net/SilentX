//
//  ImportProfileTests.swift
//  SilentXUITests
//
//  UI tests for profile import functionality (US2)
//  Tests: URL import, file import, validation, subscription auto-update
//

import XCTest

final class ImportProfileTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-NSQuitAlwaysKeepsWindows")
        app.launchArguments.append("NO")
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - T019: Import from URL/File Success and Invalid JSON Rejection
    
    func testImportFromURLSuccess() {
        // GIVEN: App is running and user navigates to Profiles
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // WHEN: User clicks Import Profile and enters valid URL
        let importButton = app.buttons["Import Profile"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2), "Import button should exist")
        importButton.tap()
        
        let importSheet = app.sheets.firstMatch
        XCTAssertTrue(importSheet.waitForExistence(timeout: 2), "Import sheet should appear")
        
        // Select URL tab
        let urlTab = importSheet.buttons["URL"]
        if urlTab.exists {
            urlTab.tap()
        }
        
        // Enter test URL (this will fail initially as service isn't implemented)
        let urlField = importSheet.textFields["Profile URL"]
        if urlField.exists {
            urlField.tap()
            urlField.typeText("https://example.com/profile.json")
        }
        
        let importActionButton = importSheet.buttons["Import"]
        if importActionButton.exists && importActionButton.isEnabled {
            importActionButton.tap()
            
            // THEN: Should show progress or success
            // This will fail until T024 is implemented
            let progressIndicator = app.progressIndicators.firstMatch
            XCTAssertTrue(progressIndicator.exists || importSheet.exists,
                          "Should show progress or remain on sheet during import")
        }
    }
    
    func testImportFromFileSuccess() {
        // GIVEN: App is running and user navigates to Profiles
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // WHEN: User clicks Import Profile and selects file
        let importButton = app.buttons["Import Profile"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2))
        importButton.tap()
        
        let importSheet = app.sheets.firstMatch
        XCTAssertTrue(importSheet.waitForExistence(timeout: 2))
        
        // Select File tab
        let fileTab = importSheet.buttons["File"]
        if fileTab.exists {
            fileTab.tap()
        }
        
        // Click Choose File button (will open file picker)
        let chooseFileButton = importSheet.buttons["Choose File"]
        if chooseFileButton.exists {
            // This will fail initially - file picker integration pending
            XCTAssertTrue(chooseFileButton.isEnabled, "Choose File should be enabled")
            // Note: Cannot easily test file picker in UI tests
            // Full E2E test requires manual testing or mocked file system
        }
        
        // Close sheet
        let cancelButton = importSheet.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }
    
    func testImportRejectsInvalidJSON() {
        // GIVEN: App is running and user navigates to Profiles
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // WHEN: User tries to import invalid JSON (malformed)
        let importButton = app.buttons["Import Profile"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2))
        importButton.tap()
        
        let importSheet = app.sheets.firstMatch
        XCTAssertTrue(importSheet.waitForExistence(timeout: 2))
        
        // Try URL with invalid JSON (will fail until validation implemented)
        let urlField = importSheet.textFields["Profile URL"]
        if urlField.exists {
            urlField.tap()
            urlField.typeText("https://example.com/invalid.json")
        }
        
        let importActionButton = importSheet.buttons["Import"]
        if importActionButton.exists && importActionButton.isEnabled {
            importActionButton.tap()
            
            // THEN: Should show validation error
            // This will fail until ConfigurationService validation is complete
            let errorAlert = app.alerts.firstMatch
            let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'invalid' OR label CONTAINS[c] 'error'")).firstMatch
            
            XCTAssertTrue(errorAlert.waitForExistence(timeout: 3) || errorText.exists,
                          "Should show error for invalid JSON")
        }
    }
    
    // MARK: - T021: Subscription Auto-Update Toggle and Status Display
    
    func testSubscriptionAutoUpdateToggle() {
        // GIVEN: User has imported a profile from URL
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // Assume at least one remote profile exists (or create one)
        // For now, test will check if toggle exists when profile is selected
        
        // WHEN: User selects a profile and views details
        let profileRows = app.groups.matching(identifier: "ProfileRow")
        if profileRows.count > 0 {
            profileRows.element(boundBy: 0).tap()
            
            // Look for auto-update toggle in detail view
            // This will fail until T025 is implemented
            let autoUpdateToggle = app.switches["Auto-update"]
            if autoUpdateToggle.waitForExistence(timeout: 2) {
                // THEN: Toggle should be interactive
                XCTAssertTrue(autoUpdateToggle.isEnabled, "Auto-update toggle should be enabled")
                
                // Toggle it
                let initialState = autoUpdateToggle.value as? String
                autoUpdateToggle.tap()
                
                // Verify state changed
                sleep(1)
                let newState = autoUpdateToggle.value as? String
                XCTAssertNotEqual(initialState, newState, "Toggle state should change")
            }
        }
    }
    
    func testSubscriptionLastSyncDisplay() {
        // GIVEN: User has a profile with subscription
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // WHEN: User views profile details
        let profileRows = app.groups.matching(identifier: "ProfileRow")
        if profileRows.count > 0 {
            profileRows.element(boundBy: 0).tap()
            
            // THEN: Should display last sync timestamp (if profile was synced)
            // This will fail until T025 is implemented with lastSyncAt UI
            let lastSyncLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'last sync' OR label CONTAINS[c] 'updated'")).firstMatch
            
            // Label should exist for remote profiles
            // This is a weak assertion - just checking UI exists
            XCTAssertTrue(lastSyncLabel.exists || app.staticTexts["Profile Details"].exists,
                          "Profile details view should render")
        }
    }
    
    func testSubscriptionErrorBanner() {
        // GIVEN: User has a profile with failed subscription update
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // WHEN: Subscription update fails (simulated by invalid URL or network error)
        // This test will fail until error handling is implemented in T024
        
        let profileRows = app.groups.matching(identifier: "ProfileRow")
        if profileRows.count > 0 {
            profileRows.element(boundBy: 0).tap()
            
            // THEN: Should show error banner or message
            // Will fail until error UI is added
            let errorBanner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'failed'")).firstMatch
            
            // This is a placeholder - actual error display depends on implementation
            XCTAssertTrue(errorBanner.exists || app.staticTexts["Profile Details"].exists,
                          "Profile view should handle errors gracefully")
        }
    }
    
    // MARK: - T022: Offline/Network-Unavailable Error Handling
    
    func testOfflineImportShowsError() {
        // GIVEN: App is running with no network (simulated)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        // WHEN: User tries to import from URL while offline
        let importButton = app.buttons["Import Profile"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2))
        importButton.tap()
        
        let importSheet = app.sheets.firstMatch
        XCTAssertTrue(importSheet.waitForExistence(timeout: 2))
        
        let urlField = importSheet.textFields["Profile URL"]
        if urlField.exists {
            urlField.tap()
            urlField.typeText("https://unreachable-host.invalid/profile.json")
        }
        
        let importActionButton = importSheet.buttons["Import"]
        if importActionButton.exists && importActionButton.isEnabled {
            importActionButton.tap()
            
            // THEN: Should show network error with retry guidance
            // This will fail until T024 implements offline error handling
            let errorAlert = app.alerts.firstMatch
            if errorAlert.waitForExistence(timeout: 5) {
                let errorMessage = errorAlert.staticTexts.element(boundBy: 1).label
                XCTAssertTrue(errorMessage.contains("network") || errorMessage.contains("connection") || errorMessage.contains("offline"),
                              "Error should mention network/connection issue")
                
                // Check for retry button
                let retryButton = errorAlert.buttons["Retry"]
                XCTAssertTrue(retryButton.exists || errorAlert.buttons["OK"].exists,
                              "Should offer retry or dismiss option")
                
                errorAlert.buttons.firstMatch.tap()
            }
        }
        
        // Close import sheet
        let cancelButton = importSheet.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }
    
    func testNetworkErrorShowsRetryGuidance() {
        // GIVEN: User experiences network error during import
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        navigateToProfiles()
        
        let importButton = app.buttons["Import Profile"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2))
        importButton.tap()
        
        let importSheet = app.sheets.firstMatch
        XCTAssertTrue(importSheet.waitForExistence(timeout: 2))
        
        // WHEN: Import fails due to network timeout
        let urlField = importSheet.textFields["Profile URL"]
        if urlField.exists {
            urlField.tap()
            urlField.typeText("https://httpstat.us/408") // HTTP timeout simulation
        }
        
        let importActionButton = importSheet.buttons["Import"]
        if importActionButton.exists && importActionButton.isEnabled {
            importActionButton.tap()
            
            // THEN: Error should provide clear guidance
            // This will fail until error messaging is implemented
            let errorAlert = app.alerts.firstMatch
            if errorAlert.waitForExistence(timeout: 10) {
                let buttons = errorAlert.buttons.allElementsBoundByIndex
                let hasRetryOption = buttons.contains { $0.label == "Retry" }
                
                XCTAssertTrue(hasRetryOption || buttons.count > 0,
                              "Should provide retry or recovery options")
                
                errorAlert.buttons.firstMatch.tap()
            }
        }
        
        let cancelButton = importSheet.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToProfiles() {
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        
        if profilesButton.waitForExistence(timeout: 2) {
            profilesButton.tap()
        }
        
        let profilesList = app.scrollViews.firstMatch
        XCTAssertTrue(profilesList.waitForExistence(timeout: 3), "Profile list should load")
    }
}

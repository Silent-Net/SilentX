//
//  ProfileListCrashTests.swift
//  SilentXUITests
//
//  Regression test for ProfileListView SwiftData query crash
//  Issue: App crashes when clicking on profile due to invalid ModelContext
//

import XCTest

final class ProfileListCrashTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Disable window restoration for tests
        app.launchArguments.append("-NSQuitAlwaysKeepsWindows")
        app.launchArguments.append("NO")
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Profile List Rendering Tests
    
    func testProfileListRendersWithoutCrash() {
        // GIVEN: App launches successfully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // WHEN: User navigates to Profiles section
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        
        if profilesButton.waitForExistence(timeout: 2) {
            profilesButton.tap()
        }
        
        // THEN: Profile list view should appear without crashing
        let profilesList = app.scrollViews.firstMatch
        XCTAssertTrue(profilesList.waitForExistence(timeout: 3),
                      "Profile list should render without crash")
        
        // Additional verification: Check for empty state or profile rows
        let emptyState = app.staticTexts["No Profiles Yet"]
        let hasEmptyState = emptyState.exists
        
        // If empty state exists, that's valid
        if hasEmptyState {
            XCTAssertTrue(emptyState.isHittable, "Empty state should be visible")
        }
        
        // App should still be running (not crashed)
        XCTAssertEqual(app.state, .runningForeground, "App should remain running")
    }
    
    func testProfileListWithExistingProfiles() {
        // GIVEN: App launches
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // WHEN: Navigate to profiles
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        
        if profilesButton.waitForExistence(timeout: 2) {
            profilesButton.tap()
        }
        
        // THEN: Can interact with profile list
        let profilesList = app.scrollViews.firstMatch
        XCTAssertTrue(profilesList.waitForExistence(timeout: 3))
        
        // Try to add a profile via import button
        let importButton = app.buttons["Import Profile"]
        if importButton.waitForExistence(timeout: 2) {
            importButton.tap()
            
            // Import sheet should appear
            let importSheet = app.sheets.firstMatch
            XCTAssertTrue(importSheet.waitForExistence(timeout: 2),
                          "Import sheet should appear")
            
            // Close sheet
            let cancelButton = importSheet.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
        
        // App should still be running
        XCTAssertEqual(app.state, .runningForeground)
    }
    
    func testProfileClickDoesNotCrash() {
        // GIVEN: App launches and navigates to profiles
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        
        if profilesButton.waitForExistence(timeout: 2) {
            profilesButton.tap()
        }
        
        // Wait for profile list
        let profilesList = app.scrollViews.firstMatch
        XCTAssertTrue(profilesList.waitForExistence(timeout: 3))
        
        // WHEN: Look for any profile rows (if they exist)
        let profileRows = app.groups.matching(identifier: "ProfileRow")
        
        if profileRows.count > 0 {
            // Click on first profile
            let firstProfile = profileRows.element(boundBy: 0)
            if firstProfile.exists && firstProfile.isHittable {
                firstProfile.tap()
                
                // THEN: App should not crash
                XCTAssertEqual(app.state, .runningForeground,
                               "App should not crash when clicking profile")
            }
        }
        
        // Even if no profiles exist, app should still be running
        XCTAssertEqual(app.state, .runningForeground)
    }
    
    func testProfileContextMenuDoesNotCrash() {
        // GIVEN: App launches and navigates to profiles with at least one profile
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        
        if profilesButton.waitForExistence(timeout: 2) {
            profilesButton.tap()
        }
        
        let profilesList = app.scrollViews.firstMatch
        XCTAssertTrue(profilesList.waitForExistence(timeout: 3))
        
        // WHEN: Right-click on a profile (if exists)
        let profileRows = app.groups.matching(identifier: "ProfileRow")
        
        if profileRows.count > 0 {
            let firstProfile = profileRows.element(boundBy: 0)
            if firstProfile.exists && firstProfile.isHittable {
                firstProfile.rightClick()
                
                // THEN: Context menu should appear without crash
                let contextMenu = app.menuItems.firstMatch
                let hasContextMenu = contextMenu.waitForExistence(timeout: 2)
                
                // Context menu may or may not appear depending on state
                // But app should not crash regardless
                XCTAssertEqual(app.state, .runningForeground,
                               "App should not crash when showing context menu")
                
                // Dismiss context menu if it appeared
                if hasContextMenu {
                    app.typeKey(.escape, modifierFlags: [])
                }
            }
        }
        
        XCTAssertEqual(app.state, .runningForeground)
    }
    
    // MARK: - SwiftData Query Integrity Tests
    
    func testMultipleNavigationsToProfileList() {
        // GIVEN: App launches
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let sidebar = app.groups["sidebar"]
        let profilesButton = sidebar.buttons["Profiles"]
        let dashboardButton = sidebar.buttons["Dashboard"]
        
        // WHEN: Navigate back and forth multiple times
        for _ in 0..<3 {
            if profilesButton.waitForExistence(timeout: 2) {
                profilesButton.tap()
                
                let profilesList = app.scrollViews.firstMatch
                XCTAssertTrue(profilesList.waitForExistence(timeout: 2),
                              "Profile list should render on navigation")
            }
            
            if dashboardButton.waitForExistence(timeout: 2) {
                dashboardButton.tap()
                sleep(1) // Allow view to settle
            }
        }
        
        // THEN: App should remain stable through multiple navigations
        XCTAssertEqual(app.state, .runningForeground,
                       "App should not crash during multiple navigations")
    }
}

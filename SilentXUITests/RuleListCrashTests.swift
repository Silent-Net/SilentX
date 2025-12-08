//
//  RuleListCrashTests.swift
//  SilentXUITests
//
//  Regression tests for RuleListView crash scenarios
//  Root cause prevention: Ensure updatedAt is stored property
//

import XCTest

/// Regression tests for rule list crash scenarios
/// Verifies that RuleListView renders without crashes
final class RuleListCrashTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Regression Tests
    
    /// Test that rule list renders without crash
    func testRuleListRendersWithoutCrash() throws {
        // Navigate to Rules
        let rulesButton = app.buttons["Rules"]
        XCTAssertTrue(rulesButton.waitForExistence(timeout: 5))
        rulesButton.tap()
        
        // Verify rule list appears (empty or with content)
        let ruleListExists = app.otherElements["RuleListView"].exists || 
                            app.staticTexts["No Rules"].exists
        XCTAssertTrue(ruleListExists, "RuleListView should render without crash")
    }
    
    /// Test that clicking on a rule doesn't crash
    func testRuleClickDoesNotCrash() throws {
        // Navigate to Rules
        app.buttons["Rules"].tap()
        
        // Add a test rule if empty
        if app.staticTexts["No Rules"].exists {
            app.buttons["Add Rule"].tap()
            app.menuItems["Add Custom Rule"].tap()
            
            // Fill in basic rule info
            let nameField = app.textFields["Rule Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 2))
            nameField.tap()
            nameField.typeText("Test Rule")
            
            let valueField = app.textFields["Match Value"]
            valueField.tap()
            valueField.typeText("example.com")
            
            // Save
            app.buttons["Save"].tap()
        }
        
        // Click on first rule
        let firstRule = app.buttons.matching(identifier: "RuleRow").firstMatch
        if firstRule.waitForExistence(timeout: 2) {
            firstRule.tap()
            
            // Verify edit sheet appears
            XCTAssertTrue(app.staticTexts["Rule Name"].waitForExistence(timeout: 2),
                         "Rule edit sheet should open without crash")
            
            // Close sheet
            app.buttons["Cancel"].tap()
        }
    }
    
    /// Test that rule context menu doesn't crash
    func testRuleContextMenuDoesNotCrash() throws {
        // Navigate to Rules
        app.buttons["Rules"].tap()
        
        // Skip if no rules
        let firstRule = app.buttons.matching(identifier: "RuleRow").firstMatch
        guard firstRule.waitForExistence(timeout: 2) else {
            throw XCTSkip("No rules available for context menu test")
        }
        
        // Right-click to show context menu
        firstRule.rightClick()
        
        // Verify context menu appears
        let editButton = app.menuItems["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2),
                     "Context menu should appear without crash")
    }
    
    /// Test that multiple navigations to rule list don't crash
    func testMultipleNavigationsToRuleList() throws {
        // Navigate to Rules multiple times
        for _ in 0..<5 {
            app.buttons["Rules"].tap()
            XCTAssertTrue(app.staticTexts["No Rules"].exists || 
                         app.otherElements["RuleListView"].exists,
                         "RuleListView should render on repeated navigation")
            
            // Navigate away
            app.buttons["Dashboard"].tap()
            XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 2))
        }
    }
    
    /// Test that add rule from template doesn't crash
    func testAddRuleFromTemplateDoesNotCrash() throws {
        // Navigate to Rules
        app.buttons["Rules"].tap()
        
        // Click Add Rule
        app.buttons["Add Rule"].tap()
        app.menuItems["Add from Template"].tap()
        
        // Verify template sheet appears
        let templateSheet = app.sheets.firstMatch
        XCTAssertTrue(templateSheet.waitForExistence(timeout: 2),
                     "Template sheet should open without crash")
        
        // Close sheet (press Escape or Cancel)
        app.typeKey(.escape, modifierFlags: [])
        
        // Verify back to rule list
        XCTAssertTrue(app.staticTexts["No Rules"].exists || 
                     app.otherElements["RuleListView"].exists)
    }
    
    /// Test that rule reordering doesn't crash
    func testRuleReorderingDoesNotCrash() throws {
        // Navigate to Rules
        app.buttons["Rules"].tap()
        
        // Skip if no rules
        let firstRule = app.buttons.matching(identifier: "RuleRow").firstMatch
        guard firstRule.waitForExistence(timeout: 2) else {
            throw XCTSkip("No rules available for reordering test")
        }
        
        // Open context menu and try to move
        firstRule.rightClick()
        
        // Check if move down option exists
        let moveDownButton = app.menuItems["Move Down"]
        if moveDownButton.exists && moveDownButton.isEnabled {
            moveDownButton.tap()
            
            // Verify app still responsive
            XCTAssertTrue(app.buttons["Rules"].exists,
                         "App should remain responsive after rule reordering")
        }
    }
}

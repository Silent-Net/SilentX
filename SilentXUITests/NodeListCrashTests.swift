//
//  NodeListCrashTests.swift
//  SilentXUITests
//
//  Regression tests for NodeListView crash scenarios
//  Root cause: @Query sorting on computed property `createdAt`
//

import XCTest

/// Regression tests for node list crash scenarios
/// Verifies that NodeListView renders without crashes after computed property fix
final class NodeListCrashTests: XCTestCase {
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
    
    /// Test that node list renders without crash
    func testNodeListRendersWithoutCrash() throws {
        // Navigate to Nodes
        let nodesButton = app.buttons["Nodes"]
        XCTAssertTrue(nodesButton.waitForExistence(timeout: 5))
        nodesButton.tap()
        
        // Verify node list appears (empty or with content)
        let nodeListExists = app.otherElements["NodeListView"].exists || 
                            app.staticTexts["No Nodes"].exists
        XCTAssertTrue(nodeListExists, "NodeListView should render without crash")
    }
    
    /// Test that clicking on a node doesn't crash
    func testNodeClickDoesNotCrash() throws {
        // Navigate to Nodes
        app.buttons["Nodes"].tap()
        
        // Add a test node if empty
        if app.staticTexts["No Nodes"].exists {
            app.buttons["Add Node"].tap()
            
            // Fill in basic node info
            let nameField = app.textFields["Node Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 2))
            nameField.tap()
            nameField.typeText("Test Node")
            
            let serverField = app.textFields["Server"]
            serverField.tap()
            serverField.typeText("test.example.com")
            
            let portField = app.textFields["Port"]
            portField.tap()
            portField.typeText("443")
            
            // Save
            app.buttons["Save"].tap()
        }
        
        // Click on first node
        let firstNode = app.buttons.matching(identifier: "NodeRow").firstMatch
        if firstNode.waitForExistence(timeout: 2) {
            firstNode.tap()
            
            // Verify detail view appears
            XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 2),
                         "Node detail view should open without crash")
        }
    }
    
    /// Test that node context menu doesn't crash
    func testNodeContextMenuDoesNotCrash() throws {
        // Navigate to Nodes
        app.buttons["Nodes"].tap()
        
        // Skip if no nodes
        let firstNode = app.buttons.matching(identifier: "NodeRow").firstMatch
        guard firstNode.waitForExistence(timeout: 2) else {
            throw XCTSkip("No nodes available for context menu test")
        }
        
        // Right-click to show context menu
        firstNode.rightClick()
        
        // Verify context menu appears
        let editButton = app.menuItems["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2),
                     "Context menu should appear without crash")
    }
    
    /// Test that test latency button doesn't crash
    func testLatencyTestDoesNotCrash() throws {
        // Navigate to Nodes
        app.buttons["Nodes"].tap()
        
        // Skip if no nodes
        let firstNode = app.buttons.matching(identifier: "NodeRow").firstMatch
        guard firstNode.waitForExistence(timeout: 2) else {
            throw XCTSkip("No nodes available for latency test")
        }
        
        // Click Test All button
        let testAllButton = app.buttons["Test All"]
        if testAllButton.exists && testAllButton.isEnabled {
            testAllButton.tap()
            
            // Wait a moment for test to complete
            sleep(1)
            
            // Verify app still responsive
            XCTAssertTrue(app.buttons["Nodes"].exists,
                         "App should remain responsive after latency test")
        }
    }
    
    /// Test that multiple navigations to node list don't crash
    func testMultipleNavigationsToNodeList() throws {
        // Navigate to Nodes multiple times
        for _ in 0..<5 {
            app.buttons["Nodes"].tap()
            XCTAssertTrue(app.staticTexts["No Nodes"].exists || 
                         app.otherElements["NodeListView"].exists,
                         "NodeListView should render on repeated navigation")
            
            // Navigate away
            app.buttons["Dashboard"].tap()
            XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 2))
        }
    }
    
    /// Test that add node sheet doesn't crash
    func testAddNodeSheetDoesNotCrash() throws {
        // Navigate to Nodes
        app.buttons["Nodes"].tap()
        
        // Click Add Node
        app.buttons["Add Node"].tap()
        
        // Verify add sheet appears
        let nameField = app.textFields["Node Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2),
                     "Add node sheet should open without crash")
        
        // Cancel
        app.buttons["Cancel"].tap()
        
        // Verify back to node list
        XCTAssertTrue(app.staticTexts["No Nodes"].exists || 
                     app.otherElements["NodeListView"].exists)
    }
}

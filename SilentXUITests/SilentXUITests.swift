//
//  SilentXUITests.swift
//  SilentXUITests
//
//  Created by xmx on 6/12/2025.
//

import XCTest

final class SilentXUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testConnectDisconnectFlow() throws {
        let app = XCUIApplication()
        app.launch()
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5), "Connect button should appear")
        connectButton.tap()
        // Expect either transition to Disconnect or an error alert; both are acceptable for CI sanity checks
        let disconnectButton = app.buttons["Disconnect"]
        let alert = app.alerts["Connection Error"]
        XCTAssertTrue(disconnectButton.waitForExistence(timeout: 10) || alert.waitForExistence(timeout: 10), "Should either connect or show error")
        if disconnectButton.exists {
            disconnectButton.tap()
        } else if alert.exists {
            alert.buttons["OK"].tap()
        }
    }

    @MainActor
    func testConnectLatencyMetric() throws {
        let app = XCUIApplication()
        app.launch()
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
        measure(metrics: [XCTClockMetric()]) {
            connectButton.tap()
            _ = app.buttons["Disconnect"].waitForExistence(timeout: 10)
        }
    }
}

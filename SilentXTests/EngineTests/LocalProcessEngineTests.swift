//
//  LocalProcessEngineTests.swift
//  SilentXTests
//
//  Unit tests for LocalProcessEngine
//

import XCTest
import Combine
@testable import SilentX

@MainActor
final class LocalProcessEngineTests: XCTestCase {
    
    var engine: LocalProcessEngine!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        engine = LocalProcessEngine()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        engine = nil
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialStatusIsDisconnected() async {
        XCTAssertEqual(engine.status, .disconnected)
    }
    
    func testEngineTypeIsLocalProcess() async {
        XCTAssertEqual(engine.engineType, .localProcess)
    }
    
    // MARK: - Validation Tests
    
    func testValidateWithMissingConfig() async {
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/nonexistent/config.json"),
            corePath: URL(fileURLWithPath: "/nonexistent/sing-box"),
            logLevel: .info
        )
        
        let errors = await engine.validate(config: config)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { error in
            if case .configNotFound = error { return true }
            return false
        })
    }
    
    func testValidateWithMissingCore() async {
        // Create a temp config file
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test-config.json")
        try? "{}".write(to: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: configPath) }
        
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: configPath,
            corePath: URL(fileURLWithPath: "/nonexistent/sing-box"),
            logLevel: .info
        )
        
        let errors = await engine.validate(config: config)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { error in
            if case .coreNotFound = error { return true }
            return false
        })
    }
    
    // MARK: - Status Publisher Tests
    
    func testStatusPublisherEmitsInitialValue() async {
        let expectation = XCTestExpectation(description: "Status publisher emits initial value")
        
        engine.statusPublisher
            .first()
            .sink { status in
                XCTAssertEqual(status, .disconnected)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Stop Without Start Tests
    
    func testStopWithoutStartThrows() async {
        do {
            try await engine.stop()
            XCTFail("Expected stop to throw when not connected")
        } catch {
            // Expected
        }
    }
    
    // MARK: - Double Start Prevention Tests
    
    func testCannotStartWhileConnecting() async {
        // This test would require mocking the process launch
        // Skipping detailed implementation for now
    }
}

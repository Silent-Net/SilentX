//
//  ProxyEngineContractTests.swift
//  SilentXTests
//
//  Contract tests verifying all ProxyEngine implementations follow the protocol contract
//

import XCTest
import Combine
@testable import SilentX

/// Protocol contract tests for ProxyEngine implementations.
/// These tests verify that all engine implementations behave consistently.
@MainActor
final class ProxyEngineContractTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Contract: Initial State
    
    /// All engines must start in disconnected state
    func testAllEnginesStartDisconnected() async {
        let engines: [any ProxyEngine] = [
            LocalProcessEngine(),
            MockProxyEngine()
        ]
        
        for engine in engines {
            XCTAssertEqual(
                engine.status,
                .disconnected,
                "\(type(of: engine)) should start disconnected"
            )
        }
    }
    
    // MARK: - Contract: Status Publisher
    
    /// All engines must have a functioning status publisher
    func testAllEnginesHaveStatusPublisher() async {
        let engines: [any ProxyEngine] = [
            LocalProcessEngine(),
            MockProxyEngine()
        ]
        
        for engine in engines {
            let expectation = XCTestExpectation(
                description: "\(type(of: engine)) status publisher works"
            )
            
            engine.statusPublisher
                .first()
                .sink { status in
                    XCTAssertEqual(status, .disconnected)
                    expectation.fulfill()
                }
                .store(in: &cancellables)
            
            await fulfillment(of: [expectation], timeout: 1.0)
        }
    }
    
    // MARK: - Contract: Engine Type
    
    /// Each engine must report a valid engine type
    func testEngineTypesAreValid() async {
        let localEngine = LocalProcessEngine()
        XCTAssertEqual(localEngine.engineType, .localProcess)
        
        let mockEngine = MockProxyEngine()
        XCTAssertEqual(mockEngine.engineType, .localProcess) // Mock defaults to localProcess
        
        #if os(macOS)
        let neEngine = NetworkExtensionEngine()
        XCTAssertEqual(neEngine.engineType, .networkExtension)
        #endif
    }
    
    // MARK: - Contract: Stop Without Start
    
    /// All engines must throw when stop is called without a prior start
    func testStopWithoutStartThrowsForAllEngines() async {
        let engines: [any ProxyEngine] = [
            LocalProcessEngine(),
            MockProxyEngine()
        ]
        
        for engine in engines {
            do {
                try await engine.stop()
                XCTFail("\(type(of: engine)) should throw when stopping without start")
            } catch {
                // Expected behavior - stop should fail when not connected
            }
        }
    }
    
    // MARK: - Contract: Validation Returns Array
    
    /// All engines must return an array from validate (even if empty)
    func testValidateReturnsArrayForAllEngines() async {
        let engines: [any ProxyEngine] = [
            LocalProcessEngine(),
            MockProxyEngine()
        ]
        
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/nonexistent"),
            corePath: URL(fileURLWithPath: "/nonexistent"),
            logLevel: .info
        )
        
        for engine in engines {
            let errors = await engine.validate(config: config)
            // Should return an array (may be empty or contain errors)
            XCTAssertNotNil(errors, "\(type(of: engine)) validate must return array")
        }
    }
    
    // MARK: - Contract: MockProxyEngine Specific
    
    func testMockEngineCanSimulateSuccess() async {
        let engine = MockProxyEngine()
        engine.shouldFailStart = false
        
        let tempConfig = FileManager.default.temporaryDirectory.appendingPathComponent("mock.json")
        try? "{}".write(to: tempConfig, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempConfig) }
        
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: tempConfig,
            corePath: URL(fileURLWithPath: "/tmp/sing-box"),
            logLevel: .info
        )
        
        do {
            try await engine.start(config: config)
            
            // Verify connected state
            if case .connected = engine.status {
                // Success
            } else {
                XCTFail("Expected connected status after successful start")
            }
            
            try await engine.stop()
            XCTAssertEqual(engine.status, .disconnected)
        } catch {
            XCTFail("MockProxyEngine should not throw when configured for success: \(error)")
        }
    }
    
    func testMockEngineCanSimulateFailure() async {
        let engine = MockProxyEngine()
        engine.shouldFailStart = true
        
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/tmp/config.json"),
            corePath: URL(fileURLWithPath: "/tmp/sing-box"),
            logLevel: .info
        )
        
        do {
            try await engine.start(config: config)
            XCTFail("Expected start to fail when shouldFailStart is true")
        } catch {
            // Expected
        }
    }
}

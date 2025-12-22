//
//  NetworkExtensionEngineTests.swift
//  SilentXTests
//
//  Unit tests for NetworkExtensionEngine
//

import XCTest
import Combine
@testable import SilentX

#if os(macOS)
@MainActor
final class NetworkExtensionEngineTests: XCTestCase {
    
    var engine: NetworkExtensionEngine!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        engine = NetworkExtensionEngine()
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
    
    func testEngineTypeIsNetworkExtension() async {
        XCTAssertEqual(engine.engineType, .networkExtension)
    }
    
    // MARK: - Validation Tests
    
    func testValidateChecksExtensionInstalled() async {
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/tmp/config.json"),
            corePath: URL(fileURLWithPath: "/tmp/sing-box"),
            logLevel: .info
        )
        
        let errors = await engine.validate(config: config)
        
        // In test environment, extension won't be installed
        // So we expect extensionNotInstalled error
        XCTAssertTrue(errors.contains { error in
            if case .extensionNotInstalled = error { return true }
            return false
        })
    }
    
    func testValidateWithMissingConfig() async {
        let config = ProxyConfiguration(
            profileId: UUID(),
            configPath: URL(fileURLWithPath: "/nonexistent/config.json"),
            corePath: URL(fileURLWithPath: "/tmp/sing-box"),
            logLevel: .info
        )
        
        let errors = await engine.validate(config: config)
        
        XCTAssertTrue(errors.contains { error in
            if case .configNotFound = error { return true }
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
    
    // MARK: - Start Without Extension Tests
    
    func testStartWithoutExtensionThrows() async {
        let tempConfig = FileManager.default.temporaryDirectory.appendingPathComponent("test.json")
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
            XCTFail("Expected start to throw when extension not installed")
        } catch {
            // Verify it's the right error
            if case ProxyError.extensionNotInstalled = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
#endif

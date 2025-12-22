//
//  SystemProxyTests.swift
//  SilentXTests
//
//  Tests for T113-T116: System proxy functionality
//  - SystemProxySettings struct validation
//  - Config parsing for proxy hints (requestedSystemProxy)
//  - Proxy application and restoration logic
//

import XCTest
@testable import SilentX

/// Test suite for system proxy functionality (T113-T116)
final class SystemProxyTests: XCTestCase {
    
    // MARK: - T113: SystemProxySettings struct tests
    
    func testSystemProxySettingsEncoding() throws {
        let settings = SystemProxySettings(
            enabled: true,
            host: "127.0.0.1",
            port: 2088,
            bypassDomains: ["localhost", "127.0.0.1", "*.local"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"enabled\":true"))
        XCTAssertTrue(json.contains("\"host\":\"127.0.0.1\""))
        XCTAssertTrue(json.contains("\"port\":2088"))
        XCTAssertTrue(json.contains("bypassDomains"))
    }
    
    func testSystemProxySettingsDecoding() throws {
        let json = """
        {
            "enabled": true,
            "host": "127.0.0.1",
            "port": 2088,
            "bypassDomains": ["localhost", "127.0.0.1"]
        }
        """
        
        let decoder = JSONDecoder()
        let settings = try decoder.decode(SystemProxySettings.self, from: json.data(using: .utf8)!)
        
        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.host, "127.0.0.1")
        XCTAssertEqual(settings.port, 2088)
        XCTAssertEqual(settings.bypassDomains, ["localhost", "127.0.0.1"])
    }
    
    func testSystemProxySettingsEquality() {
        let settings1 = SystemProxySettings(enabled: true, host: "127.0.0.1", port: 2088, bypassDomains: nil)
        let settings2 = SystemProxySettings(enabled: true, host: "127.0.0.1", port: 2088, bypassDomains: nil)
        let settings3 = SystemProxySettings(enabled: false, host: "127.0.0.1", port: 2088, bypassDomains: nil)
        
        XCTAssertEqual(settings1, settings2)
        XCTAssertNotEqual(settings1, settings3)
    }
    
    func testSystemProxySettingsWithNilBypassDomains() throws {
        let settings = SystemProxySettings(enabled: true, host: "127.0.0.1", port: 2088, bypassDomains: nil)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SystemProxySettings.self, from: data)
        
        XCTAssertTrue(decoded.enabled)
        XCTAssertNil(decoded.bypassDomains)
    }
    
    // MARK: - T116: Config parsing tests
    
    func testParseConfigWithHttpProxyEnabled() throws {
        // This config has TUN with platform.http_proxy.enabled = true
        let config = """
        {
            "inbounds": [
                {
                    "type": "tun",
                    "interface_name": "utun199",
                    "auto_route": false,
                    "platform": {
                        "http_proxy": {
                            "enabled": true,
                            "server": "127.0.0.1",
                            "server_port": 2088
                        }
                    }
                }
            ]
        }
        """
        
        let result = parseSystemProxyFromConfig(config)
        
        XCTAssertNotNil(result, "Should detect system proxy settings from config")
        XCTAssertTrue(result!.enabled)
        XCTAssertEqual(result!.host, "127.0.0.1")
        XCTAssertEqual(result!.port, 2088)
    }
    
    func testParseConfigWithHttpProxyDisabled() throws {
        let config = """
        {
            "inbounds": [
                {
                    "type": "tun",
                    "interface_name": "utun199",
                    "platform": {
                        "http_proxy": {
                            "enabled": false,
                            "server": "127.0.0.1",
                            "server_port": 2088
                        }
                    }
                }
            ]
        }
        """
        
        let result = parseSystemProxyFromConfig(config)
        
        XCTAssertNil(result, "Should NOT detect proxy when enabled=false")
    }
    
    func testParseConfigWithNoHttpProxy() throws {
        let config = """
        {
            "inbounds": [
                {
                    "type": "tun",
                    "interface_name": "utun199",
                    "auto_route": true
                }
            ]
        }
        """
        
        let result = parseSystemProxyFromConfig(config)
        
        XCTAssertNil(result, "Should NOT detect proxy when platform.http_proxy is missing")
    }
    
    func testParseConfigWithMixedInboundOnly() throws {
        let config = """
        {
            "inbounds": [
                {
                    "type": "mixed",
                    "listen": "127.0.0.1",
                    "listen_port": 2088
                }
            ]
        }
        """
        
        let result = parseSystemProxyFromConfig(config)
        
        XCTAssertNil(result, "Mixed inbound alone should NOT trigger system proxy")
    }
    
    func testParseConfigWithDefaultServer() throws {
        // Config with http_proxy but no server specified (should default to 127.0.0.1)
        let config = """
        {
            "inbounds": [
                {
                    "type": "tun",
                    "interface_name": "utun199",
                    "platform": {
                        "http_proxy": {
                            "enabled": true,
                            "server_port": 3000
                        }
                    }
                }
            ]
        }
        """
        
        let result = parseSystemProxyFromConfig(config)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.host, "127.0.0.1", "Should default to 127.0.0.1 when server not specified")
        XCTAssertEqual(result!.port, 3000)
    }
    
    // MARK: - IPCRequest with systemProxy tests
    
    func testIPCRequestWithSystemProxy() throws {
        let proxy = SystemProxySettings(enabled: true, host: "127.0.0.1", port: 2088, bypassDomains: ["localhost"])
        let request = IPCRequest.start(
            configPath: "/tmp/config.json",
            corePath: "/tmp/sing-box",
            systemProxy: proxy
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("system_proxy"))
        XCTAssertTrue(json.contains("\"port\":2088"))
    }
    
    func testIPCRequestWithoutSystemProxy() throws {
        let request = IPCRequest.start(
            configPath: "/tmp/config.json",
            corePath: "/tmp/sing-box",
            systemProxy: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(IPCRequest.self, from: data)
        
        XCTAssertNil(decoded.systemProxy)
    }
    
    // MARK: - Helper: Parse config for system proxy (mirrors CoreManager.requestedSystemProxy logic)
    
    private func parseSystemProxyFromConfig(_ configJSON: String) -> SystemProxySettings? {
        guard let data = configJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = root["inbounds"] as? [[String: Any]] else {
            return nil
        }
        
        for inbound in inbounds {
            guard (inbound["type"] as? String) == "tun" else { continue }
            guard let platform = inbound["platform"] as? [String: Any],
                  let httpProxy = platform["http_proxy"] as? [String: Any] else {
                continue
            }
            guard (httpProxy["enabled"] as? Bool) == true else { continue }
            
            let host = (httpProxy["server"] as? String) ?? "127.0.0.1"
            if let port = httpProxy["server_port"] as? Int {
                return SystemProxySettings(enabled: true, host: host, port: port, bypassDomains: ["localhost", "127.0.0.1"])
            }
        }
        return nil
    }
}

// MARK: - Integration Tests (require running service)

/// Integration tests that require the privileged helper service to be running
/// These tests verify the actual system proxy application via networksetup
final class SystemProxyIntegrationTests: XCTestCase {
    
    /// Test that we can list network services (basic networksetup access)
    func testListNetworkServices() async throws {
        let output = try runNetworksetup(["-listallnetworkservices"])
        
        XCTAssertFalse(output.isEmpty, "Should get list of network services")
        // Common services on macOS
        let hasKnownService = output.contains("Wi-Fi") || output.contains("Ethernet") || output.contains("Thunderbolt")
        XCTAssertTrue(hasKnownService, "Should contain at least one known network service")
    }
    
    /// Test reading current proxy state (non-destructive)
    func testReadProxyState() async throws {
        // Find first available service
        let services = try listNetworkServices()
        guard let service = services.first else {
            throw XCTSkip("No network services available")
        }
        
        // Read web proxy state
        let output = try runNetworksetup(["-getwebproxy", service])
        
        XCTAssertTrue(output.contains("Enabled:"), "Should contain Enabled field")
        XCTAssertTrue(output.contains("Server:"), "Should contain Server field")
        XCTAssertTrue(output.contains("Port:"), "Should contain Port field")
    }
    
    /// Test reading bypass domains (non-destructive)
    func testReadBypassDomains() async throws {
        let services = try listNetworkServices()
        guard let service = services.first else {
            throw XCTSkip("No network services available")
        }
        
        // This should not throw even if bypass list is empty
        let _ = try runNetworksetup(["-getproxybypassdomains", service])
    }
    
    // MARK: - Helper methods
    
    private func runNetworksetup(_ arguments: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = arguments
        
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        
        try proc.run()
        proc.waitUntilExit()
        
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        if proc.terminationStatus != 0 {
            throw NSError(domain: "networksetup", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: stderr.isEmpty ? stdout : stderr
            ])
        }
        
        return stdout
    }
    
    private func listNetworkServices() throws -> [String] {
        let output = try runNetworksetup(["-listallnetworkservices"])
        let lines = output.split(separator: "\n").map { String($0) }
        return lines.dropFirst().compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("*") else { return nil }
            return line
        }
    }
}

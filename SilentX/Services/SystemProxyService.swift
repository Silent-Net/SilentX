//
//  SystemProxyService.swift
//  SilentX
//
//  Handles enabling and restoring macOS system proxy settings.
//

import Foundation

protocol SystemProxyServiceProtocol {
    func enableProxy(host: String, port: Int) throws
    func restoreOriginalSettings() throws
}

/// Best-effort system proxy controller using `networksetup` CLI.
/// Falls back to no-op if commands fail, surfacing errors upstream.
final class SystemProxyService: SystemProxyServiceProtocol {
    private struct ProxySnapshot {
        let service: String
        let httpEnabled: Bool
        let httpsEnabled: Bool
        let httpHost: String
        let httpPort: Int
        let httpsHost: String
        let httpsPort: Int
    }
    
    private var snapshot: ProxySnapshot?
    private let networkServices: [String]
    
    init(networkServices: [String] = SystemProxyService.detectNetworkServices()) {
        self.networkServices = networkServices
    }
    
    func enableProxy(host: String, port: Int) throws {
        guard !networkServices.isEmpty else {
            // No-op fallback when sandboxed
            if FeatureFlags.allowProxyNoopFallback {
                return
            }
            throw SystemProxyError.commandFailed("No network services detected. Admin permissions may be required.")
        }
        
        try networkServices.forEach { service in
            let current = try readCurrentState(service: service)
            snapshot = current
            
            // Set HTTP proxy
            try setProxy(service: service, host: host, port: port, enable: true)
            // Set HTTPS proxy
            try setProxy(service: service, host: host, port: port, enable: true, secure: true)
            // Set SOCKS proxy to the same port (mixed inbound handles all)
            try setSOCKSProxy(service: service, host: host, port: port, enable: true)
        }
    }
    
    func restoreOriginalSettings() throws {
        guard let snap = snapshot else { return }
        try setProxy(service: snap.service, host: snap.httpHost, port: snap.httpPort, enable: snap.httpEnabled)
        try setProxy(service: snap.service, host: snap.httpsHost, port: snap.httpsPort, enable: snap.httpsEnabled, secure: true)
    }
    
    // MARK: - Helpers
    
    private func readCurrentState(service: String) throws -> ProxySnapshot {
        let http = try readProxy(service: service, secure: false)
        let https = try readProxy(service: service, secure: true)
        return ProxySnapshot(
            service: service,
            httpEnabled: http.enabled,
            httpsEnabled: https.enabled,
            httpHost: http.host,
            httpPort: http.port,
            httpsHost: https.host,
            httpsPort: https.port
        )
    }
    
    private func readProxy(service: String, secure: Bool) throws -> (enabled: Bool, host: String, port: Int) {
        let flag = secure ? "-getsecurewebproxy" : "-getwebproxy"
        let output = try runNetworkSetup(args: [flag, service])
        let lines = output.split(separator: "\n").map(String.init)
        var enabled = false
        var host = ""
        var port = 0
        for line in lines {
            if line.lowercased().contains("enabled: yes") {
                enabled = true
            }
            if line.lowercased().contains("server:"), let value = line.split(separator: ":").last {
                host = value.trimmingCharacters(in: .whitespaces)
            }
            if line.lowercased().contains("port:"), let value = line.split(separator: ":").last, let p = Int(value.trimmingCharacters(in: .whitespaces)) {
                port = p
            }
        }
        return (enabled, host, port)
    }
    
    private func setProxy(service: String, host: String, port: Int, enable: Bool, secure: Bool = false) throws {
        let setCmd = secure ? "-setsecurewebproxy" : "-setwebproxy"
        let stateCmd = secure ? "-setsecurewebproxystate" : "-setwebproxystate"
        if enable {
            _ = try runNetworkSetup(args: [setCmd, service, host, String(port)])
            _ = try runNetworkSetup(args: [stateCmd, service, "on"])
        } else {
            _ = try runNetworkSetup(args: [stateCmd, service, "off"])
        }
    }
    
    private func setSOCKSProxy(service: String, host: String, port: Int, enable: Bool) throws {
        if enable {
            _ = try runNetworkSetup(args: ["-setsocksfirewallproxy", service, host, String(port)])
            _ = try runNetworkSetup(args: ["-setsocksfirewallproxystate", service, "on"])
        } else {
            _ = try runNetworkSetup(args: ["-setsocksfirewallproxystate", service, "off"])
        }
    }
    
    private func runNetworkSetup(args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw SystemProxyError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
    
    static func detectNetworkServices() -> [String] {
        // Sandboxed app cannot reliably call networksetup; return empty
        // Real implementation would check entitlements or use alternative detection
        if FeatureFlags.allowProxyNoopFallback {
            return []
        }
        
        // Future: non-sandboxed or with proper entitlements
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listallnetworkservices"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else { return [] }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").map(String.init)
            return lines.filter { !$0.contains("*") && !$0.isEmpty }
        } catch {
            return []
        }
    }
}

enum SystemProxyError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "System proxy update failed: \(message)"
        }
    }
}

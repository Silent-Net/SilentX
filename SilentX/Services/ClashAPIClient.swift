//
//  ClashAPIClient.swift
//  SilentX
//
//  HTTP client for Clash API (sing-box compatible)
//

import Foundation
import OSLog

/// Client for interacting with Clash API
actor ClashAPIClient {
    
    // MARK: - Types
    
    enum ClashAPIError: LocalizedError {
        case notConnected
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Proxy not connected"
            case .invalidURL:
                return "Invalid API URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response"
            case .apiError(let message):
                return "API error: \(message)"
            case .timeout:
                return "Request timeout"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "ClashAPIClient")
    private let session: URLSession
    private var baseURL: URL?
    
    // NOTE: No default port - must be configured from profile config
    // via ConnectionService.connect() which reads external_controller
    
    // MARK: - Singleton
    
    static let shared = ClashAPIClient()
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Configuration
    
    /// Configure the API client with a port
    func configure(port: Int) {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")
        logger.info("Configured Clash API at port \(port)")
    }
    
    /// Configure with URL string
    func configure(urlString: String) {
        self.baseURL = URL(string: urlString)
        logger.info("Configured Clash API at \(urlString)")
    }
    
    /// Check if API is reachable
    func isAvailable() async -> Bool {
        guard let baseURL else { return false }
        
        do {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 2
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - API Methods
    
    /// Get all proxies and groups
    /// Returns a ClashProxiesResponse with ordered keys preserved from JSON
    func getProxies() async throws -> ClashProxiesResponse {
        guard let baseURL else {
            throw ClashAPIError.notConnected
        }
        
        let url = baseURL.appendingPathComponent("proxies")
        logger.debug("GET \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ClashAPIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            // Parse JSON manually to preserve key order
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let proxiesDict = json["proxies"] as? [String: Any] else {
                throw ClashAPIError.invalidResponse
            }
            
            // Get ordered keys using NSJSONSerialization which preserves insertion order
            // Note: In Python 3.7+ and modern JSON parsers, order is typically preserved
            let orderedKeys = (proxiesDict as NSDictionary).allKeys as? [String] ?? Array(proxiesDict.keys)
            
            // Decode individual proxy info
            var proxies: [String: ClashProxyInfo] = [:]
            for (key, value) in proxiesDict {
                if let valueData = try? JSONSerialization.data(withJSONObject: value),
                   let proxyInfo = try? JSONDecoder().decode(ClashProxyInfo.self, from: valueData) {
                    proxies[key] = proxyInfo
                }
            }
            
            logger.debug("Got \(proxies.count) proxies, ordered keys: \(orderedKeys.prefix(5))")
            return ClashProxiesResponse(proxies: proxies, orderedKeys: orderedKeys)
            
        } catch let error as ClashAPIError {
            throw error
        } catch is DecodingError {
            logger.error("Failed to decode proxies response")
            throw ClashAPIError.invalidResponse
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw ClashAPIError.networkError(error)
        }
    }
    
    /// Get specific proxy info
    func getProxy(name: String) async throws -> ClashProxyInfo {
        guard let baseURL else {
            throw ClashAPIError.notConnected
        }
        
        let url = baseURL.appendingPathComponent("proxies/\(name)")
        logger.debug("GET \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ClashAPIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            return try JSONDecoder().decode(ClashProxyInfo.self, from: data)
            
        } catch let error as ClashAPIError {
            throw error
        } catch is DecodingError {
            throw ClashAPIError.invalidResponse
        } catch {
            throw ClashAPIError.networkError(error)
        }
    }
    
    /// Select a node in a selector group
    func selectProxy(group: String, node: String) async throws {
        guard let baseURL else {
            throw ClashAPIError.notConnected
        }
        
        let url = baseURL.appendingPathComponent("proxies/\(group)")
        logger.info("PUT \(url.absoluteString) -> \(node)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": node]
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashAPIError.invalidResponse
            }
            
            // 204 No Content is success
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                throw ClashAPIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            logger.info("Successfully selected \(node) in \(group)")
            
        } catch let error as ClashAPIError {
            throw error
        } catch {
            throw ClashAPIError.networkError(error)
        }
    }
    
    /// Test latency for a specific proxy
    func getDelay(
        proxy: String,
        testURL: String = "http://www.gstatic.com/generate_204",
        timeout: Int = 5000
    ) async throws -> Int {
        guard let baseURL else {
            throw ClashAPIError.notConnected
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("proxies/\(proxy)/delay"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "url", value: testURL),
            URLQueryItem(name: "timeout", value: String(timeout))
        ]
        
        guard let url = components.url else {
            throw ClashAPIError.invalidURL
        }
        
        logger.debug("GET \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = TimeInterval(timeout / 1000 + 2)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let result = try JSONDecoder().decode(ClashDelayResponse.self, from: data)
                if let delay = result.delay {
                    logger.debug("\(proxy) delay: \(delay)ms")
                    return delay
                }
            }
            
            // Timeout or error
            if let result = try? JSONDecoder().decode(ClashDelayResponse.self, from: data),
               let message = result.message {
                logger.warning("\(proxy) delay test failed: \(message)")
            }
            return -1 // Indicate timeout/error
            
        } catch let error as ClashAPIError {
            throw error
        } catch is URLError {
            return -1 // Timeout
        } catch {
            throw ClashAPIError.networkError(error)
        }
    }
    
    /// Test latency for multiple proxies concurrently
    func getDelays(
        proxies: [String],
        testURL: String = "http://www.gstatic.com/generate_204",
        timeout: Int = 5000
    ) async -> [String: Int] {
        await withTaskGroup(of: (String, Int).self) { group in
            for proxy in proxies {
                group.addTask {
                    do {
                        let delay = try await self.getDelay(proxy: proxy, testURL: testURL, timeout: timeout)
                        return (proxy, delay)
                    } catch {
                        return (proxy, -1)
                    }
                }
            }
            
            var results: [String: Int] = [:]
            for await (proxy, delay) in group {
                results[proxy] = delay
            }
            return results
        }
    }
    
    /// Change proxy mode (rule/global/direct)
    func setMode(_ mode: String) async throws {
        guard let baseURL else {
            throw ClashAPIError.notConnected
        }
        
        let url = baseURL.appendingPathComponent("configs")
        logger.debug("PATCH \(url.absoluteString) mode=\(mode)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["mode": mode]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw ClashAPIError.apiError("Failed to set mode: HTTP \(httpResponse.statusCode)")
            }
            
            logger.info("Mode changed to: \(mode)")
            
        } catch let error as ClashAPIError {
            throw error
        } catch {
            throw ClashAPIError.networkError(error)
        }
    }
    
    /// Get current mode
    func getMode() async throws -> String {
        guard let baseURL else {
            throw ClashAPIError.notConnected
        }
        
        let url = baseURL.appendingPathComponent("configs")
        logger.debug("GET \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ClashAPIError.invalidResponse
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let mode = json["mode"] as? String {
                return mode
            }
            
            return "rule" // Default
            
        } catch let error as ClashAPIError {
            throw error
        } catch {
            throw ClashAPIError.networkError(error)
        }
    }
}

// MARK: - Helpers

extension ClashAPIClient {
    
    /// Parse groups from proxies response, maintaining original order from config
    func parseGroups(from response: ClashProxiesResponse) -> [OutboundGroup] {
        var groups: [OutboundGroup] = []
        let proxies = response.proxies
        
        // Use ordered keys to maintain original config order
        for tag in response.orderedKeys {
            guard let info = proxies[tag] else { continue }
            
            // Only include entries that have 'all' field (these are groups)
            guard let members = info.all else { continue }
            
            // Skip GLOBAL and other special groups
            if tag == "GLOBAL" || tag == "DIRECT" || tag == "REJECT" {
                continue
            }
            
            let items = members.compactMap { memberTag -> OutboundGroupItem? in
                let memberInfo = proxies[memberTag]
                return OutboundGroupItem(
                    id: memberTag,
                    tag: memberTag,
                    type: memberInfo?.type ?? "Unknown",
                    delay: memberInfo?.latestDelay,
                    isSelected: memberTag == info.now
                )
            }
            
            let group = OutboundGroup(
                id: tag,
                tag: tag,
                type: info.type,
                selected: info.now ?? "",
                selectable: info.selectable,
                items: items
            )
            
            groups.append(group)
        }
        
        // DO NOT sort - maintain original order from config file
        // This matches SFM behavior where groups appear in config-defined order
        
        return groups
    }
}

//
//  GitHubReleaseService.swift
//  SilentX
//
//  Service for fetching sing-box releases from GitHub API
//

import Foundation

/// Service for interacting with GitHub Releases API
protocol GitHubReleaseServiceProtocol {
    /// Fetch paginated list of releases
    func fetchReleases(page: Int) async throws -> [GitHubRelease]
    
    /// Fetch the latest stable release
    func fetchLatestRelease() async throws -> GitHubRelease
    
    /// Fetch a specific release by tag name
    func fetchReleaseByTag(_ tag: String) async throws -> GitHubRelease
}

/// Real implementation of GitHub Releases API client
final class GitHubReleaseService: GitHubReleaseServiceProtocol {
    
    // MARK: - Properties
    
    private let baseURL = "https://api.github.com/repos/SagerNet/sing-box"
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared) {
        self.session = session
        
        // Configure JSON decoder for GitHub's date format
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    func fetchReleases(page: Int = 1) async throws -> [GitHubRelease] {
        guard page > 0 else {
            throw CoreVersionError.invalidURL
        }
        
        let urlString = "\(baseURL)/releases?page=\(page)&per_page=30"
        guard let url = URL(string: urlString) else {
            throw CoreVersionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Check for rate limiting
            if let httpResponse = response as? HTTPURLResponse {
                try checkRateLimit(httpResponse)
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw CoreVersionError.networkError(statusCode: httpResponse.statusCode)
                }
            }
            
            let releases = try decoder.decode([GitHubRelease].self, from: data)
            return releases
            
        } catch let error as CoreVersionError {
            throw error
        } catch let error as DecodingError {
            throw CoreVersionError.decodingFailed(error.localizedDescription)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw CoreVersionError.networkUnavailable
            } else if error.code == .timedOut {
                throw CoreVersionError.networkError(statusCode: 408)
            } else {
                throw CoreVersionError.networkError(statusCode: error.code.rawValue)
            }
        } catch {
            throw CoreVersionError.networkError(statusCode: 0)
        }
    }
    
    func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "\(baseURL)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw CoreVersionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                try checkRateLimit(httpResponse)
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw CoreVersionError.networkError(statusCode: httpResponse.statusCode)
                }
            }
            
            let release = try decoder.decode(GitHubRelease.self, from: data)
            return release
            
        } catch let error as CoreVersionError {
            throw error
        } catch let error as DecodingError {
            throw CoreVersionError.decodingFailed(error.localizedDescription)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw CoreVersionError.networkUnavailable
            } else if error.code == .timedOut {
                throw CoreVersionError.networkError(statusCode: 408)
            } else {
                throw CoreVersionError.networkError(statusCode: error.code.rawValue)
            }
        } catch {
            throw CoreVersionError.networkError(statusCode: 0)
        }
    }
    
    func fetchReleaseByTag(_ tag: String) async throws -> GitHubRelease {
        let urlString = "\(baseURL)/releases/tags/\(tag)"
        guard let url = URL(string: urlString) else {
            throw CoreVersionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                try checkRateLimit(httpResponse)
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 404 {
                        throw CoreVersionError.versionNotFound(tag)
                    }
                    throw CoreVersionError.networkError(statusCode: httpResponse.statusCode)
                }
            }
            
            let release = try decoder.decode(GitHubRelease.self, from: data)
            return release
            
        } catch let error as CoreVersionError {
            throw error
        } catch let error as DecodingError {
            throw CoreVersionError.decodingFailed(error.localizedDescription)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw CoreVersionError.networkUnavailable
            } else if error.code == .timedOut {
                throw CoreVersionError.networkError(statusCode: 408)
            } else {
                throw CoreVersionError.networkError(statusCode: error.code.rawValue)
            }
        } catch {
            throw CoreVersionError.networkError(statusCode: 0)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkRateLimit(_ response: HTTPURLResponse) throws {
        // Check if rate limit exceeded
        if response.statusCode == 403,
           let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           remaining == "0",
           let resetString = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTimestamp = TimeInterval(resetString) {
            let resetDate = Date(timeIntervalSince1970: resetTimestamp)
            throw CoreVersionError.rateLimitExceeded(resetTime: resetDate)
        }
    }
}

// MARK: - Mock Implementation

/// Mock implementation for testing and previews
final class MockGitHubReleaseService: GitHubReleaseServiceProtocol {
    
    var mockReleases: [GitHubRelease] = []
    var shouldThrowError: CoreVersionError?
    
    init(mockReleases: [GitHubRelease] = []) {
        self.mockReleases = mockReleases.isEmpty ? Self.createDefaultMockReleases() : mockReleases
    }
    
    func fetchReleases(page: Int) async throws -> [GitHubRelease] {
        if let error = shouldThrowError {
            throw error
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
        
        return mockReleases
    }
    
    func fetchLatestRelease() async throws -> GitHubRelease {
        if let error = shouldThrowError {
            throw error
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        guard let latest = mockReleases.first(where: { !$0.prerelease }) else {
            throw CoreVersionError.versionNotFound("latest")
        }
        
        return latest
    }
    
    func fetchReleaseByTag(_ tag: String) async throws -> GitHubRelease {
        if let error = shouldThrowError {
            throw error
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        guard let release = mockReleases.first(where: { $0.tagName == tag }) else {
            throw CoreVersionError.versionNotFound(tag)
        }
        
        return release
    }
    
    static func createDefaultMockReleases() -> [GitHubRelease] {
        return [
            GitHubRelease(
                id: 1,
                tagName: "v1.9.0",
                name: "1.9.0",
                prerelease: false,
                publishedAt: "2025-11-29T00:00:00Z",
                assets: [
                    GitHubAsset(
                        id: 101,
                        name: "sing-box-1.9.0-darwin-arm64.tar.gz",
                        size: 15_728_640,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-darwin-arm64.tar.gz"
                    ),
                    GitHubAsset(
                        id: 102,
                        name: "sing-box-1.9.0-darwin-amd64.tar.gz",
                        size: 16_777_216,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-darwin-amd64.tar.gz"
                    )
                ]
            ),
            GitHubRelease(
                id: 2,
                tagName: "v1.8.14",
                name: "1.8.14",
                prerelease: false,
                publishedAt: "2025-11-06T00:00:00Z",
                assets: [
                    GitHubAsset(
                        id: 201,
                        name: "sing-box-1.8.14-darwin-arm64.tar.gz",
                        size: 14_680_064,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.8.14/sing-box-1.8.14-darwin-arm64.tar.gz"
                    )
                ]
            )
        ]
    }
}

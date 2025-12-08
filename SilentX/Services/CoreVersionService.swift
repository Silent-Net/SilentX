//
//  CoreVersionService.swift
//  SilentX
//
//  Service for managing Sing-Box core versions
//

import Foundation
import Combine
import SwiftData

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the main download function
    }
}

/// Represents a GitHub release for Sing-Box
struct GitHubRelease: Codable, Identifiable, Hashable {
    let id: Int
    let tagName: String
    let name: String
    let prerelease: Bool
    let publishedAt: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
    
    /// Version string without 'v' prefix
    var versionString: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
    
    /// Find the macOS binary asset
    var macOSAsset: GitHubAsset? {
        assets.first { asset in
            let name = asset.name.lowercased()
            return name.contains("darwin") && 
                   (name.contains("arm64") || name.contains("amd64")) &&
                   (name.hasSuffix(".tar.gz") || name.hasSuffix(".zip"))
        }
    }
    
    // Hashable conformance
    static func == (lhs: GitHubRelease, rhs: GitHubRelease) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a downloadable asset from GitHub
struct GitHubAsset: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let size: Int
    let browserDownloadURL: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case browserDownloadURL = "browser_download_url"
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

/// Protocol for core version service operations
protocol CoreVersionServiceProtocol: ObservableObject {
    /// All cached (downloaded) core versions
    var cachedVersions: [CoreVersion] { get }
    
    /// Currently active version
    var activeVersion: CoreVersion? { get }
    
    /// Available releases from GitHub
    var availableReleases: [GitHubRelease] { get }
    
    /// Download progress (0.0 - 1.0)
    var downloadProgress: Double { get }
    
    /// Whether currently downloading
    var isDownloading: Bool { get }
    
    /// Fetch available releases from GitHub
    func fetchAvailableReleases() async throws
    
    /// Download a specific version
    func downloadVersion(_ release: GitHubRelease) async throws
    
    /// Download from a custom URL
    func downloadFromURL(_ url: URL, versionName: String) async throws
    
    /// Set active version
    func setActiveVersion(_ version: CoreVersion) throws
    
    /// Delete a cached version
    func deleteVersion(_ version: CoreVersion) throws
    
    /// Check for updates
    func checkForUpdates() async throws -> GitHubRelease?
}

/// Implementation of CoreVersionService with real GitHub API integration
@MainActor
final class CoreVersionService: CoreVersionServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var cachedVersions: [CoreVersion] = []
    @Published private(set) var activeVersion: CoreVersion?
    @Published private(set) var availableReleases: [GitHubRelease] = []
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var isDownloading: Bool = false
    
    // MARK: - Private Properties
    
    private let githubService: GitHubReleaseServiceProtocol
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(githubService: GitHubReleaseServiceProtocol = GitHubReleaseService(), modelContext: ModelContext) {
        self.githubService = githubService
        self.modelContext = modelContext
        loadPersistedVersions()
    }
    
    // MARK: - Public Methods
    
    func fetchAvailableReleases() async throws {
        // Fetch from real GitHub API
        let releases = try await githubService.fetchReleases(page: 1)
        availableReleases = releases
    }
    
    func downloadVersion(_ release: GitHubRelease) async throws {
        guard !isDownloading else { return }
        
        // Check if already downloaded
        let descriptor = FetchDescriptor<CoreVersion>(predicate: #Predicate { $0.version == release.versionString })
        let existing = try? modelContext.fetch(descriptor)
        if existing?.isEmpty == false {
            throw CoreVersionError.alreadyDownloaded
        }
        
        guard let asset = release.macOSAsset,
              let downloadURL = URL(string: asset.browserDownloadURL) else {
            throw CoreVersionError.downloadFailed("No macOS asset found")
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        defer {
            isDownloading = false
        }

        // Download to temporary location with unique name
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sing-box-\(release.versionString)-\(UUID().uuidString).tar.gz")

        // Remove existing temp file if any
        try? FileManager.default.removeItem(at: tempURL)
        
        // Create download task with progress tracking
        let delegate = DownloadDelegate { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress
            }
        }
        
        // Construct session on MainActor to silence actor isolation warning
        let session = await MainActor.run { URLSession(configuration: .default, delegate: delegate, delegateQueue: nil) }
        let (localURL, response) = try await session.download(from: downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CoreVersionError.downloadFailed("HTTP error")
        }
        
        // Move to temp location
        try FileManager.default.moveItem(at: localURL, to: tempURL)
        
        // Extract tar.gz
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sing-box-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        
        let tarProcess = Process()
        tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tarProcess.arguments = ["-xzf", tempURL.path, "-C", extractDir.path]
        try tarProcess.run()
        tarProcess.waitUntilExit()
        
        // Find sing-box binary
        guard let binaryURL = findBinaryInDirectory(extractDir) else {
            throw CoreVersionError.downloadFailed("Binary not found in archive")
        }
        
        // Create final destination aligned with FilePath.cores
        let appSupport = FilePath.corePath(for: release.versionString)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let finalURL = appSupport.appendingPathComponent("sing-box")

        // Remove existing binary if any
        try? FileManager.default.removeItem(at: finalURL)

        // Copy, remove quarantine, and make executable
        try FileManager.default.copyItem(at: binaryURL, to: finalURL)
        removeQuarantine(at: finalURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: finalURL.path)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: extractDir)
        
        // Create new cached version and persist
        let newVersion = CoreVersion(
            version: release.versionString,
            downloadURL: downloadURL.absoluteString,
            isPrerelease: release.prerelease
        )
        newVersion.downloadDate = Date()
        newVersion.localPath = finalURL.path
        
        modelContext.insert(newVersion)
        try modelContext.save()
        
        // Auto-activate the first downloaded core when none is active
        if activeVersion == nil {
            try setActiveVersion(newVersion)
        } else {
            loadPersistedVersions()
        }
    }
    
    private func findBinaryInDirectory(_ url: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isExecutableKey]) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "sing-box" {
                return fileURL
            }
        }
        return nil
    }

    private func removeQuarantine(at url: URL) {
        // Use xattr command instead of removexattr() syscall
        // because App Sandbox silently ignores removexattr for quarantine attribute
        // Run async to avoid blocking main thread during SwiftUI view updates
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            process.arguments = ["-d", "com.apple.quarantine", url.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
    
    func downloadFromURL(_ url: URL, versionName: String) async throws {
        guard !isDownloading else { return }
        
        // Validate URL
        guard url.scheme == "https" || url.scheme == "http" else {
            throw CoreVersionError.invalidURL
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        defer {
            isDownloading = false
        }
        
        // Simulate download progress
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 200_000_000)
            downloadProgress = Double(i) / 10.0
        }
        
        // Create new cached version and persist
        let newVersion = CoreVersion(
            version: versionName,
            downloadURL: url.absoluteString
        )
        newVersion.downloadDate = Date()
        newVersion.localPath = "/Applications/SilentX.app/Contents/Resources/sing-box-\(versionName)"
        
        modelContext.insert(newVersion)
        try modelContext.save()
        
        loadPersistedVersions()
    }
    
    func setActiveVersion(_ version: CoreVersion) throws {
        // Deactivate ALL versions first
        let allVersions = try modelContext.fetch(FetchDescriptor<CoreVersion>())
        for v in allVersions {
            v.isActive = false
        }
        
        // Activate new version
        version.isActive = true
        activeVersion = version
        
        try modelContext.save()
        loadPersistedVersions()
    }
    
    func deleteVersion(_ version: CoreVersion) throws {
        // Cannot delete active version
        if version.isActive {
            throw CoreVersionError.versionInUse
        }
        
        modelContext.delete(version)
        try modelContext.save()
        
        loadPersistedVersions()
    }
    
    func checkForUpdates() async throws -> GitHubRelease? {
        try await fetchAvailableReleases()
        
        guard let currentVersion = activeVersion?.version else {
            return availableReleases.first
        }
        
        // Check if latest release is newer than current
        if let latestRelease = availableReleases.first,
           latestRelease.versionString != currentVersion {
            return latestRelease
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func loadPersistedVersions() {
        let descriptor = FetchDescriptor<CoreVersion>(sortBy: [SortDescriptor(\.downloadDate, order: .reverse)])
        
        do {
            let versions = try modelContext.fetch(descriptor)
            // Ensure downloaded binaries are not quarantined
            versions.forEach { version in
                if let path = version.localPath {
                    removeQuarantine(at: URL(fileURLWithPath: path))
                }
            }
            cachedVersions = versions
            activeVersion = versions.first(where: { $0.isActive })
        } catch {
            print("Failed to load persisted versions: \(error)")
            cachedVersions = []
            activeVersion = nil
        }
    }
    

    
    private func createMockReleases() -> [GitHubRelease] {
        return [
            GitHubRelease(
                id: 1,
                tagName: "v1.9.1",
                name: "1.9.1",
                prerelease: false,
                publishedAt: "2024-01-15T00:00:00Z",
                assets: [
                    GitHubAsset(
                        id: 101,
                        name: "sing-box-1.9.1-darwin-arm64.tar.gz",
                        size: 15_500_000,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.1/sing-box-1.9.1-darwin-arm64.tar.gz"
                    ),
                    GitHubAsset(
                        id: 102,
                        name: "sing-box-1.9.1-darwin-amd64.tar.gz",
                        size: 16_000_000,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.1/sing-box-1.9.1-darwin-amd64.tar.gz"
                    )
                ]
            ),
            GitHubRelease(
                id: 2,
                tagName: "v1.9.0",
                name: "1.9.0",
                prerelease: false,
                publishedAt: "2024-01-01T00:00:00Z",
                assets: [
                    GitHubAsset(
                        id: 201,
                        name: "sing-box-1.9.0-darwin-arm64.tar.gz",
                        size: 15_000_000,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-darwin-arm64.tar.gz"
                    )
                ]
            ),
            GitHubRelease(
                id: 3,
                tagName: "v1.9.0-rc.1",
                name: "1.9.0 Release Candidate 1",
                prerelease: true,
                publishedAt: "2023-12-20T00:00:00Z",
                assets: [
                    GitHubAsset(
                        id: 301,
                        name: "sing-box-1.9.0-rc.1-darwin-arm64.tar.gz",
                        size: 14_800_000,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.9.0-rc.1/sing-box-1.9.0-rc.1-darwin-arm64.tar.gz"
                    )
                ]
            ),
            GitHubRelease(
                id: 4,
                tagName: "v1.8.14",
                name: "1.8.14",
                prerelease: false,
                publishedAt: "2023-12-01T00:00:00Z",
                assets: [
                    GitHubAsset(
                        id: 401,
                        name: "sing-box-1.8.14-darwin-arm64.tar.gz",
                        size: 14_500_000,
                        browserDownloadURL: "https://github.com/SagerNet/sing-box/releases/download/v1.8.14/sing-box-1.8.14-darwin-arm64.tar.gz"
                    )
                ]
            )
        ]
    }
}

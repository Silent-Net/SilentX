//
//  ProfileService.swift
//  SilentX
//
//  Profile management service for CRUD operations and profile selection
//

import Foundation
import SwiftData
import Combine

/// Protocol for profile management operations
protocol ProfileServiceProtocol {
    /// Gets the currently active (selected) profile
    func getActiveProfile(context: ModelContext) -> Profile?
    
    /// Sets a profile as the active profile
    func setActiveProfile(_ profile: Profile, context: ModelContext) throws
    
    /// Clears the active profile selection
    func clearActiveProfile(context: ModelContext) throws
    
    /// Creates a new profile
    func createProfile(name: String, type: ProfileType, configurationJSON: String, context: ModelContext) throws -> Profile
    
    /// Deletes a profile
    func deleteProfile(_ profile: Profile, context: ModelContext) throws
    
    /// Updates a profile's configuration
    func updateConfiguration(_ profile: Profile, json: String, context: ModelContext) throws
    
    /// Imports a profile from URL (subscription or direct config)
    func importFromURL(_ url: URL, name: String?, context: ModelContext) async throws -> Profile
    
    /// Imports a profile from a local file
    func importFromFile(_ fileURL: URL, name: String?, context: ModelContext) throws -> Profile
    
    /// Exports a profile to JSON data
    func exportToJSON(_ profile: Profile) throws -> Data
    
    /// Refreshes a remote profile
    func refreshRemoteProfile(_ profile: Profile, context: ModelContext) async throws
}

/// Implementation of ProfileService
@MainActor
final class ProfileService: ProfileServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ProfileService(configurationService: ConfigurationService())
    
    // MARK: - Private Properties
    
    private let configurationService: any ConfigurationServiceProtocol
    
    // MARK: - Initialization
    
    init(configurationService: any ConfigurationServiceProtocol) {
        self.configurationService = configurationService
    }
    
    // MARK: - Profile Selection
    
    func getActiveProfile(context: ModelContext) -> Profile? {
        let descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.isSelected }
        )
        
        do {
            let profiles = try context.fetch(descriptor)
            return profiles.first
        } catch {
            print("Failed to fetch active profile: \(error)")
            return nil
        }
    }
    
    func setActiveProfile(_ profile: Profile, context: ModelContext) throws {
        // First, deselect all profiles
        try clearActiveProfile(context: context)
        
        // Select the specified profile
        profile.isSelected = true
        
        try context.save()
    }
    
    func clearActiveProfile(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.isSelected }
        )
        
        let selectedProfiles = try context.fetch(descriptor)
        for profile in selectedProfiles {
            profile.isSelected = false
        }
        
        try context.save()
    }
    
    // MARK: - CRUD Operations
    
    func createProfile(name: String, type: ProfileType, configurationJSON: String, context: ModelContext) throws -> Profile {
        // Validate configuration first
        let validationResult = configurationService.validate(json: configurationJSON)
        guard validationResult.isValid else {
            throw ProfileError.invalidConfiguration(validationResult.errors.first?.message ?? "Invalid configuration")
        }
        
        // Create and insert the profile
        let profile = Profile(
            name: name,
            type: type,
            configurationJSON: configurationJSON
        )
        
        context.insert(profile)
        try context.save()
        
        return profile
    }
    
    func deleteProfile(_ profile: Profile, context: ModelContext) throws {
        // If this was the selected profile, clear selection
        if profile.isSelected {
            profile.isSelected = false
        }
        
        context.delete(profile)
        try context.save()
    }
    
    func updateConfiguration(_ profile: Profile, json: String, context: ModelContext) throws {
        // Validate configuration first
        let validationResult = configurationService.validate(json: json)
        guard validationResult.isValid else {
            throw ProfileError.invalidConfiguration(validationResult.errors.first?.message ?? "Invalid configuration")
        }
        
        profile.configurationJSON = json
        profile.updatedAt = Date()
        
        try context.save()
    }
    
    // MARK: - Import Operations
    
    func importFromURL(_ url: URL, name: String?, context: ModelContext) async throws -> Profile {
        // Download configuration from URL
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ProfileError.downloadFailed("Server returned an error")
        }
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ProfileError.invalidConfiguration("Could not decode configuration as UTF-8")
        }
        
        // Validate configuration
        let validationResult = configurationService.validate(json: jsonString)
        guard validationResult.isValid else {
            throw ProfileError.invalidConfiguration(validationResult.errors.first?.message ?? "Invalid configuration")
        }
        
        // Create profile
        let profileName = name ?? url.lastPathComponent.replacingOccurrences(of: ".json", with: "")
        let profile = Profile(
            name: profileName,
            type: .remote,
            configurationJSON: jsonString,
            remoteURL: url.absoluteString
        )
        profile.lastSyncAt = Date()
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            profile.subscriptionETag = etag
        }
        if let modified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
            profile.subscriptionLastModified = modified
        }
        
        context.insert(profile)
        try context.save()
        
        return profile
    }
    
    func importFromFile(_ fileURL: URL, name: String?, context: ModelContext) throws -> Profile {
        // Read file contents
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw ProfileError.fileAccessDenied
        }
        
        defer {
            fileURL.stopAccessingSecurityScopedResource()
        }
        
        let data = try Data(contentsOf: fileURL)
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ProfileError.invalidConfiguration("Could not decode file as UTF-8")
        }
        
        // Validate configuration
        let validationResult = configurationService.validate(json: jsonString)
        guard validationResult.isValid else {
            throw ProfileError.invalidConfiguration(validationResult.errors.first?.message ?? "Invalid configuration")
        }
        
        // Create profile
        let profileName = name ?? fileURL.deletingPathExtension().lastPathComponent
        let profile = Profile(
            name: profileName,
            type: .local,
            configurationJSON: jsonString
        )
        
        context.insert(profile)
        try context.save()
        
        return profile
    }
    
    // MARK: - Export Operations
    
    func exportToJSON(_ profile: Profile) throws -> Data {
        guard let data = profile.configurationJSON.data(using: .utf8) else {
            throw ProfileError.exportFailed("Could not encode configuration as UTF-8")
        }
        return data
    }
    
    // MARK: - Remote Profile Operations
    
    func refreshRemoteProfile(_ profile: Profile, context: ModelContext) async throws {
        guard profile.type == .remote,
              let urlString = profile.remoteURL,
              let url = URL(string: urlString) else {
            throw ProfileError.notRemoteProfile
        }
        var request = URLRequest(url: url)
        if let etag = profile.subscriptionETag {
            request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = profile.subscriptionLastModified {
            request.addValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.downloadFailed("No HTTP response")
        }
        if httpResponse.statusCode == 304 {
            profile.lastSyncAt = Date()
            profile.lastSyncStatus = "Up to date"
            try context.save()
            return
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProfileError.downloadFailed("Server returned status \(httpResponse.statusCode)")
        }
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ProfileError.invalidConfiguration("Could not decode configuration as UTF-8")
        }
        let validationResult = configurationService.validate(json: jsonString)
        guard validationResult.isValid else {
            throw ProfileError.invalidConfiguration(validationResult.errors.first?.message ?? "Invalid configuration")
        }
        profile.configurationJSON = jsonString
        profile.updatedAt = Date()
        profile.lastSyncAt = Date()
        profile.lastSyncStatus = "Updated"
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            profile.subscriptionETag = etag
        }
        if let modified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
            profile.subscriptionLastModified = modified
        }
        try context.save()
    }

    // MARK: - Subscription Refresh
    func refreshAutoUpdatedProfiles(context: ModelContext) async {
        let descriptor = FetchDescriptor<Profile>(predicate: #Predicate { $0.autoUpdate })
        guard let profiles = try? context.fetch(descriptor) else { return }
        for profile in profiles {
            do {
                try await refreshRemoteProfile(profile, context: context)
            } catch {
                profile.lastSyncStatus = error.localizedDescription
                try? context.save()
            }
        }
    }
    
    // MARK: - T024: Subscription Updater with Retry/Backoff and Merge Safety
    
    /// Update a remote profile with exponential backoff retry for transient errors
    /// - Parameters:
    ///   - profile: Profile to update (must be remote type with autoUpdate enabled)
    ///   - context: SwiftData ModelContext for persistence
    ///   - maxRetries: Maximum retry attempts (default: 3)
    func updateSubscription(_ profile: Profile, context: ModelContext, maxRetries: Int = 3) async throws {
        guard profile.type == .remote,
              let urlString = profile.remoteURL,
              let url = URL(string: urlString) else {
            throw ProfileError.notRemoteProfile
        }
        
        var retryCount = 0
        var backoffDelay: TimeInterval = 5.0 // Start with 5 seconds
        
        while retryCount <= maxRetries {
            do {
                // Build request with conditional headers (ETag/Last-Modified)
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                
                if let etag = profile.subscriptionETag {
                    request.addValue(etag, forHTTPHeaderField: "If-None-Match")
                }
                if let lastModified = profile.subscriptionLastModified {
                    request.addValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
                }
                
                // Perform fetch
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ProfileError.downloadFailed("No HTTP response")
                }
                
                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 304:
                    // Not Modified - content unchanged, update sync timestamp only
                    profile.lastSyncAt = Date()
                    profile.lastSyncStatus = "Up to date (304)"
                    try context.save()
                    return
                    
                case 200...299:
                    // Success - process new content
                    try await processSubscriptionUpdate(
                        profile: profile,
                        data: data,
                        httpResponse: httpResponse,
                        context: context
                    )
                    return
                    
                case 429:
                    // Rate limit - retry with longer backoff
                    throw ProfileError.rateLimited
                    
                case 404, 410:
                    // Permanent errors - don't retry
                    throw ProfileError.downloadFailed("Resource not found (HTTP \(httpResponse.statusCode))")
                    
                case 400...499:
                    // Client errors - don't retry (except 429 handled above)
                    throw ProfileError.downloadFailed("Client error (HTTP \(httpResponse.statusCode))")
                    
                case 500...599:
                    // Server errors - retry with backoff
                    throw ProfileError.serverError(httpResponse.statusCode)
                    
                default:
                    throw ProfileError.downloadFailed("Unexpected status \(httpResponse.statusCode)")
                }
                
            } catch let error as ProfileError {
                // Handle known errors
                if case .rateLimited = error {
                    // For rate limiting, use longer backoff
                    backoffDelay = min(backoffDelay * 2, 300) // Cap at 5 minutes
                    retryCount += 1
                    
                    if retryCount <= maxRetries {
                        profile.lastSyncStatus = "Rate limited, retrying in \(Int(backoffDelay))s..."
                        try? context.save()
                        try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                        continue
                    }
                } else if case .serverError(_) = error {
                    // Server errors - retry with backoff
                    backoffDelay = min(backoffDelay * 2, 300)
                    retryCount += 1
                    
                    if retryCount <= maxRetries {
                        profile.lastSyncStatus = "Server error, retrying in \(Int(backoffDelay))s..."
                        try? context.save()
                        try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                        continue
                    }
                }
                
                // Permanent error or exhausted retries
                profile.lastSyncAt = Date()
                profile.lastSyncStatus = "Failed: \(error.localizedDescription)"
                try? context.save()
                throw error
                
            } catch {
                // Handle network errors (timeouts, connection failures)
                if (error as NSError).domain == NSURLErrorDomain {
                    let nsError = error as NSError
                    
                    // Transient network errors - retry
                    if [NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost].contains(nsError.code) {
                        backoffDelay = min(backoffDelay * 2, 300)
                        retryCount += 1
                        
                        if retryCount <= maxRetries {
                            profile.lastSyncStatus = "Network error, retrying in \(Int(backoffDelay))s..."
                            try? context.save()
                            try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                            continue
                        }
                    }
                }
                
                // Other errors - fail immediately
                profile.lastSyncAt = Date()
                profile.lastSyncStatus = "Failed: \(error.localizedDescription)"
                try? context.save()
                throw error
            }
        }
        
        // Exhausted all retries
        profile.lastSyncAt = Date()
        profile.lastSyncStatus = "Failed after \(maxRetries) retries"
        try context.save()
        throw ProfileError.downloadFailed("Maximum retries exceeded")
    }
    
    /// Process subscription update with merge conflict detection
    private func processSubscriptionUpdate(
        profile: Profile,
        data: Data,
        httpResponse: HTTPURLResponse,
        context: ModelContext
    ) async throws {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ProfileError.invalidConfiguration("Could not decode configuration as UTF-8")
        }
        
        // Validate new configuration before applying
        let validationResult = configurationService.validate(json: jsonString)
        guard validationResult.isValid else {
            throw ProfileError.invalidConfiguration(validationResult.errors.first?.message ?? "Invalid configuration from remote")
        }
        
        // Detect merge conflict: local edits since last sync
        let hasLocalEdits = profile.lastSyncAt != nil && profile.updatedAt > profile.lastSyncAt!
        
        if hasLocalEdits {
            // User has made local changes since last sync
            // Check if remote content is different from current
            let isDifferent = jsonString != profile.configurationJSON
            
            if isDifferent {
                // CONFLICT: Both local and remote have changes
                // For now, we'll favor remote (subscription source of truth)
                // TODO: Implement three-way merge or user prompt in T025 UI
                profile.configurationJSON = jsonString
                profile.lastSyncStatus = "Updated (local changes overwritten)"
            } else {
                // Remote matches local - no conflict
                profile.lastSyncStatus = "Up to date"
            }
        } else {
            // No local edits - safe to update
            let isDifferent = jsonString != profile.configurationJSON
            
            if isDifferent {
                profile.configurationJSON = jsonString
                profile.updatedAt = Date()
                profile.lastSyncStatus = "Updated"
            } else {
                profile.lastSyncStatus = "Up to date (content unchanged)"
            }
        }
        
        // Update metadata
        profile.lastSyncAt = Date()
        
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            profile.subscriptionETag = etag
        }
        if let modified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
            profile.subscriptionLastModified = modified
        }
        
        try context.save()
    }
}

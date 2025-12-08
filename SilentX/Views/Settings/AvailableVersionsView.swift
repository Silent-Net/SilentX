//
//  AvailableVersionsView.swift
//  SilentX
//
//  View for browsing and downloading GitHub releases
//

import SwiftUI
import SwiftData

/// View for displaying available Sing-Box releases from GitHub
struct AvailableVersionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coreVersionService: CoreVersionService
    
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showPreReleases = false
    @State private var selectedRelease: GitHubRelease?
    @State private var showDownloadConfirmation = false
    
    private var filteredReleases: [GitHubRelease] {
        if showPreReleases {
            return coreVersionService.availableReleases
        } else {
            return coreVersionService.availableReleases.filter { !$0.prerelease }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Available Releases")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Show Pre-releases", isOn: $showPreReleases)
                    .toggleStyle(.checkbox)
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Fetching releases from GitHub...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task {
                            await loadReleases()
                        }
                    }
                }
            } else if filteredReleases.isEmpty {
                ContentUnavailableView(
                    "No Releases",
                    systemImage: "tray",
                    description: Text("No releases found matching your criteria.")
                )
            } else {
                List(filteredReleases, selection: $selectedRelease) { release in
                    ReleaseRowView(
                        release: release,
                        isDownloaded: isDownloaded(release)
                    )
                    .tag(release)
                }
                .listStyle(.inset)
            }
            
            // Download progress
            if coreVersionService.isDownloading {
                Divider()
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(coreVersionService.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressView(value: coreVersionService.downloadProgress)
                        .progressViewStyle(.linear)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
            }
            
            Divider()
            
            // Actions
            HStack {
                Button {
                    Task {
                        await loadReleases()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button {
                    showDownloadConfirmation = true
                } label: {
                    Text("Download")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRelease == nil || 
                          isDownloaded(selectedRelease) ||
                          coreVersionService.isDownloading)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 560, height: 480)
        .task {
            await loadReleases()
        }
        .confirmationDialog(
            "Download Release",
            isPresented: $showDownloadConfirmation,
            presenting: selectedRelease
        ) { release in
            Button("Download v\(release.versionString)") {
                Task {
                    await downloadRelease(release)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { release in
            if let asset = release.macOSAsset {
                Text("Download \(asset.name) (\(asset.formattedSize))?")
            } else {
                Text("Download version \(release.versionString)?")
            }
        }
    }
    
    private func loadReleases() async {
        isLoading = true
        loadError = nil
        
        do {
            try await coreVersionService.fetchAvailableReleases()
        } catch {
            loadError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func downloadRelease(_ release: GitHubRelease) async {
        do {
            try await coreVersionService.downloadVersion(release)
        } catch {
            loadError = error.localizedDescription
        }
    }
    
    private func isDownloaded(_ release: GitHubRelease?) -> Bool {
        guard let release = release else { return false }
        return coreVersionService.cachedVersions.contains { $0.version == release.versionString }
    }
}

/// Row view for a single GitHub release
struct ReleaseRowView: View {
    let release: GitHubRelease
    let isDownloaded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Version icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(release.prerelease ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: release.prerelease ? "hammer" : "shippingbox")
                    .font(.title3)
                    .foregroundStyle(release.prerelease ? .orange : .blue)
            }
            
            // Release info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("v\(release.versionString)")
                        .font(.headline)
                    
                    if release.prerelease {
                        Text("PRE-RELEASE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    
                    if isDownloaded {
                        Text("DOWNLOADED")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    // Published date
                    Label(formattedDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Asset size if available
                    if let asset = release.macOSAsset {
                        Label(asset.formattedSize, systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Platform indicator
            if release.macOSAsset != nil {
                Label("macOS", systemImage: "laptopcomputer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("No macOS", systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .opacity(isDownloaded ? 0.6 : 1.0)
    }
    
    private var formattedDate: String {
        // Parse ISO date string
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: release.publishedAt) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return release.publishedAt
    }
}

#Preview {
    AvailableVersionsView(coreVersionService: {
        let context = ModelContext(SilentXApp.sharedModelContainer)
        return CoreVersionService(modelContext: context)
    }())
}

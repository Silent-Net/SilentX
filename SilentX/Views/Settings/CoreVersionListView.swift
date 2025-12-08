//
//  CoreVersionListView.swift
//  SilentX
//
//  List view for managing Sing-Box core versions
//

import SwiftUI
import SwiftData

/// Main view for managing core versions
struct CoreVersionListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var coreVersionService: CoreVersionService
    @State private var showDownloadSheet = false
    @State private var showAvailableVersions = false
    @State private var selectedVersion: CoreVersion?
    @State private var showDeleteConfirmation = false
    @State private var versionToDelete: CoreVersion?
    @State private var isCheckingForUpdates = false
    @State private var updateAvailable: GitHubRelease?
    @State private var showError = false
    @State private var errorMessage = ""
    
    init() {
        let context = ModelContext(SilentXApp.sharedModelContainer)
        _coreVersionService = StateObject(wrappedValue: CoreVersionService(modelContext: context))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Downloaded versions list
            List(selection: $selectedVersion) {
                Section("Downloaded Versions") {
                    if coreVersionService.cachedVersions.isEmpty {
                        ContentUnavailableView(
                            "No Core Versions",
                            systemImage: "cpu",
                            description: Text("Download a Sing-Box core version to get started.")
                        )
                    } else {
                        ForEach(coreVersionService.cachedVersions) { version in
                            CoreVersionRowView(
                                version: version,
                                isActive: version.id == coreVersionService.activeVersion?.id
                            )
                            .tag(version)
                            .contextMenu {
                                versionContextMenu(for: version)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            
            // Download progress
            if coreVersionService.isDownloading {
                downloadProgressView
            }
        }
        .navigationTitle("Core Versions")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await checkForUpdates()
                    }
                } label: {
                    if isCheckingForUpdates {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isCheckingForUpdates)
                
                Button {
                    showAvailableVersions = true
                } label: {
                    Label("Browse Releases", systemImage: "list.bullet.rectangle")
                }
                
                Button {
                    showDownloadSheet = true
                } label: {
                    Label("Download from URL", systemImage: "link.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showDownloadSheet) {
            DownloadCoreSheet(coreVersionService: coreVersionService)
        }
        .sheet(isPresented: $showAvailableVersions) {
            AvailableVersionsView(coreVersionService: coreVersionService)
        }
        .alert("Update Available", isPresented: .init(
            get: { updateAvailable != nil },
            set: { if !$0 { updateAvailable = nil } }
        )) {
            Button("Download") {
                if let release = updateAvailable {
                    Task {
                        try? await coreVersionService.downloadVersion(release)
                    }
                }
            }
            Button("Later", role: .cancel) { }
        } message: {
            if let release = updateAvailable {
                Text("Version \(release.versionString) is available. Would you like to download it?")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "Delete Version",
            isPresented: $showDeleteConfirmation,
            presenting: versionToDelete
        ) { version in
            Button("Delete", role: .destructive) {
                deleteVersion(version)
            }
            Button("Cancel", role: .cancel) { }
        } message: { version in
            Text("Are you sure you want to delete version \(version.version)?")
        }
    }
    
    private var downloadProgressView: some View {
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
    
    @ViewBuilder
    private func versionContextMenu(for version: CoreVersion) -> some View {
        if !version.isActive {
            Button {
                setActive(version)
            } label: {
                Label("Set as Active", systemImage: "checkmark.circle")
            }
        }
        
        Divider()
        
        Button {
            if let path = version.localPath {
                let url = URL(fileURLWithPath: path).deletingLastPathComponent()
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: url.path)
            }
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        .disabled(version.localPath == nil)
        
        Divider()
        
        Button(role: .destructive) {
            versionToDelete = version
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(version.isActive)
    }
    
    private func setActive(_ version: CoreVersion) {
        do {
            try coreVersionService.setActiveVersion(version)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func deleteVersion(_ version: CoreVersion) {
        do {
            try coreVersionService.deleteVersion(version)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func checkForUpdates() async {
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        
        do {
            updateAvailable = try await coreVersionService.checkForUpdates()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        CoreVersionListView()
    }
}

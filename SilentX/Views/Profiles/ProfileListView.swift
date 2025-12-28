//
//  ProfileListView.swift
//  SilentX
//
//  List view displaying all profiles with SwiftData @Query
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main profile list view
struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var connectionService: ConnectionService
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    
    // SwiftData query with explicit sort descriptor to avoid crashes
    @Query(
        sort: [SortDescriptor(\Profile.updatedAt, order: .reverse)],
        animation: .default
    ) private var profiles: [Profile]
    
    @State private var showImportSheet = false
    @State private var showDeleteAlert = false
    @State private var profileToDelete: Profile?
    @State private var isTargeted = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var profileToRename: Profile?
    @State private var profileToEdit: Profile?
    @State private var newProfileName: String = ""
    
    var body: some View {
        Group {
            if profiles.isEmpty {
                EmptyProfilesView(showImportSheet: $showImportSheet)
            } else {
                profileList
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImportSheet = true
                } label: {
                    Label("Import Profile", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportProfileSheet()
        }
        .alert("Delete Profile", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(profileToDelete?.name ?? "")\"? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        // Rename alert
        .alert("Rename Profile", isPresented: Binding(
            get: { profileToRename != nil },
            set: { if !$0 { profileToRename = nil } }
        )) {
            TextField("Profile Name", text: $newProfileName)
            Button("Cancel", role: .cancel) {
                profileToRename = nil
            }
            Button("Rename") {
                if let profile = profileToRename {
                    renameProfile(profile, to: newProfileName)
                }
                profileToRename = nil
            }
        } message: {
            Text("Enter a new name for this profile.")
        }
        // Edit config sheet
        .sheet(item: $profileToEdit) { profile in
            ProfileEditorView(profile: profile)
        }
        .onDrop(of: [.json, .fileURL], isTargeted: $isTargeted) { providers in
            handleFileDrop(providers)
            return true
        }
        .overlay {
            if isTargeted {
                dropOverlay
            }
        }
    }
    
    private var profileList: some View {
        List {
            ForEach(profiles) { profile in
                ProfileRowView(profile: profile)
                    .contextMenu {
                        profileContextMenu(for: profile)
                    }
            }
            .onDelete(perform: deleteProfiles)
        }
        .listStyle(.inset)
    }
    
    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.2)
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Drop configuration files here")
                    .font(.headline)
                Text("JSON files supported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    @ViewBuilder
    private func profileContextMenu(for profile: Profile) -> some View {
        Button {
            selectProfile(profile)
        } label: {
            Label("Set as Active", systemImage: "checkmark.circle")
        }
        .disabled(profile.isSelected)
        
        Divider()
        
        Button {
            newProfileName = profile.name
            profileToRename = profile
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        Button {
            profileToEdit = profile
        } label: {
            Label("Edit Config", systemImage: "doc.text")
        }
        
        if profile.type == .remote {
            Button {
                Task {
                    await refreshProfile(profile)
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        
        Button {
            exportProfile(profile)
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button(role: .destructive) {
            profileToDelete = profile
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func selectProfile(_ profile: Profile) {
        // Deselect all profiles
        for p in profiles {
            p.isSelected = false
        }
        // Select this profile
        profile.isSelected = true
        
        // Save the selected profile ID for Dashboard sync
        selectedProfileID = profile.id.uuidString
        
        try? modelContext.save()
        
        // If connected, restart with the new profile immediately (SFM-like instant switch)
        if case .connected = connectionService.status {
            Task {
                do {
                    try await connectionService.disconnect()
                    try await connectionService.connect(profile: profile)
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(profiles[index])
        }
        try? modelContext.save()
    }
    
    private func renameProfile(_ profile: Profile, to newName: String) {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        profile.name = newName.trimmingCharacters(in: .whitespaces)
        profile.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func deleteProfile(_ profile: Profile) {
        modelContext.delete(profile)
        try? modelContext.save()
    }
    
    private func exportProfile(_ profile: Profile) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(profile.name).json"
        savePanel.title = "Export Profile"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let data = profile.configurationJSON.data(using: .utf8) ?? Data()
                    try data.write(to: url)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func refreshProfile(_ profile: Profile) async {
        guard let urlString = profile.remoteURL,
              let url = URL(string: urlString) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let jsonString = String(data: data, encoding: .utf8) {
                profile.configurationJSON = jsonString
                profile.lastSyncAt = Date()
                profile.updatedAt = Date()
                try modelContext.save()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    guard let url = url else { return }
                    
                    Task { @MainActor in
                        do {
                            let data = try Data(contentsOf: url)
                            guard let jsonString = String(data: data, encoding: .utf8) else {
                                throw ProfileError.invalidConfiguration("Invalid file encoding")
                            }
                            
                            let profile = Profile(
                                name: url.deletingPathExtension().lastPathComponent,
                                type: .local,
                                configurationJSON: jsonString
                            )
                            
                            modelContext.insert(profile)
                            try modelContext.save()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileListView()
    }
    .modelContainer(for: Profile.self, inMemory: true)
}

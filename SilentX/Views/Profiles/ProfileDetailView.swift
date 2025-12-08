//
//  ProfileDetailView.swift
//  SilentX
//
//  Detail view for viewing and editing profile information
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Detail view for a single profile
struct ProfileDetailView: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var modelContext
    
    @State private var showJSONEditor = false
    @State private var showDeleteAlert = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                profileHeader
                
                Divider()
                
                // Profile info section
                infoSection
                
                Divider()
                
                // Configuration section
                configurationSection
                
                Divider()
                
                // Nodes summary
                if !profile.nodes.isEmpty {
                    nodesSection
                    Divider()
                }
                
                // Rules summary
                if !profile.rules.isEmpty {
                    rulesSection
                    Divider()
                }
                
                // Actions section
                actionsSection
            }
            .padding()
        }
        .navigationTitle(profile.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showJSONEditor = true
                    } label: {
                        Label("Edit JSON", systemImage: "curlybraces")
                    }
                    
                    if profile.type == .remote {
                        Button {
                            Task { await refreshProfile() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showJSONEditor) {
            JSONEditorView(
                jsonText: $profile.configurationJSON,
                profileName: profile.name
            ) { newJSON in
                profile.configurationJSON = newJSON
                profile.updatedAt = Date()
                try? modelContext.save()
            }
        }
        .alert("Delete Profile", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteProfile()
            }
        } message: {
            Text("Are you sure you want to delete \"\(profile.name)\"? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Subviews
    
    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Profile type icon
            ZStack {
                Circle()
                    .fill(profile.type.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: profile.type.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(profile.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if profile.isSelected {
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text(profile.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !profile.isSelected {
                Button("Set Active") {
                    setAsActive()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)
            
            LabeledContent("Created") {
                Text(profile.createdAt.formatted(date: .long, time: .shortened))
            }
            
            LabeledContent("Last Updated") {
                Text(profile.updatedAt.formatted(date: .long, time: .shortened))
            }
            
            if profile.type == .remote, let url = profile.remoteURL {
                LabeledContent("Remote URL") {
                    Text(url)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                // T025: Subscription auto-update controls
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Auto-update", isOn: $profile.autoUpdate)
                        .toggleStyle(.switch)
                        .onChange(of: profile.autoUpdate) { _, newValue in
                            try? modelContext.save()
                            // Start first sync if enabled
                            if newValue {
                                Task { await refreshProfileWithRetry() }
                            }
                        }
                    
                    if profile.autoUpdate {
                        Picker("Update Interval", selection: $profile.autoUpdateInterval) {
                            Text("6 hours").tag(6)
                            Text("12 hours").tag(12)
                            Text("24 hours").tag(24)
                            Text("48 hours").tag(48)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: profile.autoUpdateInterval) { _, _ in
                            try? modelContext.save()
                        }
                    }
                }
                
                // Sync status with error banner
                if let status = profile.lastSyncStatus {
                    let isError = status.lowercased().contains("error") || status.lowercased().contains("failed")
                    
                    LabeledContent("Sync Status") {
                        HStack {
                            Text(status)
                                .foregroundStyle(isError ? .red : .secondary)
                            
                            if isError {
                                Button {
                                    Task { await refreshProfileWithRetry() }
                                } label: {
                                    Label("Retry", systemImage: "arrow.clockwise")
                                        .labelStyle(.iconOnly)
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(isRefreshing)
                            }
                        }
                    }
                }
                
                if let lastSync = profile.lastSyncAt {
                    LabeledContent("Last Sync") {
                        HStack {
                            Text(lastSync.formatted(.relative(presentation: .numeric)))
                            
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                        }
                    }
                }
                
                // Manual refresh button for remote profiles
                if !isRefreshing {
                    Button {
                        Task { await refreshProfileWithRetry() }
                    } label: {
                        Label("Refresh Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Configuration")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showJSONEditor = true
                } label: {
                    Label("Edit JSON", systemImage: "pencil")
                }
                .buttonStyle(.borderless)
            }
            
            // Configuration preview
            ScrollView(.horizontal, showsIndicators: false) {
                Text(profile.configurationJSON.prefix(500))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxHeight: 120)
        }
    }
    
    private var nodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proxy Nodes")
                    .font(.headline)
                
                Spacer()
                
                Text("\(profile.nodes.count)")
                    .foregroundStyle(.secondary)
            }
            
            ForEach(profile.nodes.prefix(5)) { node in
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                    Text(node.name)
                    Spacer()
                    Text(node.protocolType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            
            if profile.nodes.count > 5 {
                Text("+ \(profile.nodes.count - 5) more nodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Routing Rules")
                    .font(.headline)
                
                Spacer()
                
                Text("\(profile.rules.count)")
                    .foregroundStyle(.secondary)
            }
            
            ForEach(profile.rules.sorted(by: { $0.priority < $1.priority }).prefix(5)) { rule in
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.secondary)
                    Text(rule.matchValue)
                        .lineLimit(1)
                    Spacer()
                    Text(rule.action.rawValue)
                        .font(.caption)
                        .foregroundStyle(rule.action.color)
                }
                .padding(.vertical, 2)
            }
            
            if profile.rules.count > 5 {
                Text("+ \(profile.rules.count - 5) more rules")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button {
                    exportProfile()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    duplicateProfile()
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                
                if profile.type == .remote {
                    Button {
                        Task { await refreshProfile() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Actions
    
    private func setAsActive() {
        // Deselect all profiles first
        let descriptor = FetchDescriptor<Profile>()
        if let allProfiles = try? modelContext.fetch(descriptor) {
            for p in allProfiles {
                p.isSelected = false
            }
        }
        
        // Select this profile
        profile.isSelected = true
        try? modelContext.save()
    }
    
    // T025: Enhanced refresh using new subscription updater with retry/backoff
    private func refreshProfileWithRetry() async {
        guard let urlString = profile.remoteURL,
              URL(string: urlString) != nil else {
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let service = ProfileService.shared
            // Use new updateSubscription method with retry logic
            try await service.updateSubscription(profile, context: modelContext, maxRetries: 3)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // Legacy refresh method (kept for backward compatibility)
    private func refreshProfile() async {
        guard let urlString = profile.remoteURL,
              URL(string: urlString) != nil else {
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let service = ProfileService.shared
            try await service.refreshRemoteProfile(profile, context: modelContext)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func exportProfile() {
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
    
    private func duplicateProfile() {
        let duplicate = Profile(
            name: "\(profile.name) Copy",
            type: .local,
            configurationJSON: profile.configurationJSON
        )
        
        modelContext.insert(duplicate)
        try? modelContext.save()
    }
    
    private func deleteProfile() {
        modelContext.delete(profile)
        try? modelContext.save()
    }
}

/// Sheet for editing JSON
struct JSONEditorSheet: View {
    @Bindable var profile: Profile
    @Environment(\.dismiss) private var dismiss
    
    @State private var jsonText: String = ""
    @State private var validationError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = validationError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                }
                
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding()
            }
            .navigationTitle("Edit Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(validationError != nil)
                }
            }
        }
        .onAppear {
            jsonText = profile.configurationJSON
        }
        .onChange(of: jsonText) { _, newValue in
            validateJSON(newValue)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private func validateJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else {
            validationError = "Invalid encoding"
            return
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            validationError = nil
        } catch {
            validationError = error.localizedDescription
        }
    }
    
    private func saveConfiguration() {
        profile.configurationJSON = jsonText
        profile.updatedAt = Date()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProfileDetailView(profile: Profile(
            name: "Test Profile",
            type: .remote,
            configurationJSON: "{\n  \"outbounds\": []\n}",
            remoteURL: "https://example.com/config.json"
        ))
    }
    .modelContainer(for: Profile.self, inMemory: true)
}

//
//  ProfileEditorView.swift
//  SilentX
//
//  Simple JSON editor for profile configuration
//

import SwiftUI
import SwiftData

/// Profile configuration editor view
struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let profile: Profile
    
    @State private var configText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Configuration")
                        .font(.headline)
                    Text(profile.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Validation status
                if let error = errorMessage {
                    Label("Invalid JSON", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Save") {
                    saveConfig()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || errorMessage != nil)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Text editor
            TextEditor(text: $configText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: configText) { _, newValue in
                    validateJSON(newValue)
                }
            
            // Footer with tips
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Edit the sing-box configuration JSON. Press ⌘S to save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(configText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            configText = formatJSON(profile.configurationJSON)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func validateJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else {
            errorMessage = "Invalid UTF-8"
            return
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            errorMessage = nil
        } catch {
            errorMessage = "Invalid JSON: \(error.localizedDescription)"
        }
    }
    
    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: formatted, encoding: .utf8) else {
            return json
        }
        return result
    }
    
    private func saveConfig() {
        guard errorMessage == nil else { return }
        
        isSaving = true
        
        // Minify JSON for storage (remove pretty printing)
        let minified: String
        if let data = configText.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let compact = try? JSONSerialization.data(withJSONObject: obj),
           let result = String(data: compact, encoding: .utf8) {
            minified = result
        } else {
            minified = configText
        }
        
        profile.configurationJSON = minified
        profile.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSaving = false
    }
}

#Preview {
    let container = try! ModelContainer(for: Profile.self, configurations: .init(isStoredInMemoryOnly: true))
    let profile = Profile(
        name: "Test Profile",
        type: .local,
        configurationJSON: "{\"log\":{\"level\":\"info\"},\"inbounds\":[],\"outbounds\":[]}"
    )
    container.mainContext.insert(profile)
    
    return ProfileEditorView(profile: profile)
        .modelContainer(container)
}

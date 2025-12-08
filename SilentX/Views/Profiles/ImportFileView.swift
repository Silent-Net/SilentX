//
//  ImportFileView.swift
//  SilentX
//
//  View for importing profiles from local files
//

import SwiftUI
import UniformTypeIdentifiers

/// View for importing a profile from a local file
struct ImportFileView: View {
    let onImport: (Profile) -> Void
    
    @State private var profileName = ""
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showFilePicker = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    if let fileName = selectedFileName {
                        Label(fileName, systemImage: "doc.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No file selected")
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Button("Choose File...") {
                        showFilePicker = true
                    }
                }
                
                TextField("Profile Name (Optional)", text: $profileName, prompt: Text("Auto-detect from filename"))
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Select a Sing-Box configuration file")
            } footer: {
                Text("Supported formats: JSON (.json)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    Spacer()
                    
                    Button {
                        importFromFile()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        } else {
                            Text("Import")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedFileURL == nil || isLoading)
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func importFromFile() {
        guard let url = selectedFileURL else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file. Please grant permission."
            showError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw ProfileError.invalidConfiguration("Could not decode file as UTF-8")
            }
            
            // Validate JSON
            guard let _ = try? JSONSerialization.jsonObject(with: data) else {
                throw ProfileError.invalidConfiguration("Invalid JSON format")
            }
            
            // Create profile
            let name = profileName.isEmpty 
                ? url.deletingPathExtension().lastPathComponent
                : profileName
            
            let profile = Profile(
                name: name,
                type: .local,
                configurationJSON: jsonString
            )
            
            onImport(profile)
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    ImportFileView { _ in }
        .frame(width: 500, height: 300)
}

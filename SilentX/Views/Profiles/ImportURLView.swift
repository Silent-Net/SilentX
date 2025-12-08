//
//  ImportURLView.swift
//  SilentX
//
//  View for importing profiles from URL
//

import SwiftUI

/// View for importing a profile from a URL
struct ImportURLView: View {
    let onImport: (Profile) -> Void
    
    @State private var urlString = ""
    @State private var profileName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var isValidURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Profile URL", text: $urlString, prompt: Text("https://example.com/config.json"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                
                TextField("Profile Name (Optional)", text: $profileName, prompt: Text("Auto-detect from URL"))
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Enter the URL to a Sing-Box configuration file")
            } footer: {
                Text("Supports direct JSON files and subscription links")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    Spacer()
                    
                    Button {
                        Task { await importFromURL() }
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
                    .disabled(!isValidURL || isLoading)
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func importFromURL() async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            showError = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ProfileError.downloadFailed("Server returned an error")
            }
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw ProfileError.invalidConfiguration("Could not decode as UTF-8")
            }
            
            // Validate JSON
            guard let _ = try? JSONSerialization.jsonObject(with: data) else {
                throw ProfileError.invalidConfiguration("Invalid JSON format")
            }
            
            // Create profile
            let name = profileName.isEmpty 
                ? url.lastPathComponent.replacingOccurrences(of: ".json", with: "")
                : profileName
            
            let profile = Profile(
                name: name,
                type: .remote,
                configurationJSON: jsonString,
                remoteURL: urlString
            )
            
            await MainActor.run {
                onImport(profile)
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ImportURLView { _ in }
        .frame(width: 500, height: 300)
}

//
//  DownloadCoreSheet.swift
//  SilentX
//
//  Sheet for downloading core version from custom URL
//

import SwiftUI
import SwiftData

/// Sheet view for downloading Sing-Box core from a custom URL
struct DownloadCoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coreVersionService: CoreVersionService
    
    @State private var urlString = ""
    @State private var versionName = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var isDownloading = false
    
    private var isValidInput: Bool {
        guard let url = URL(string: urlString) else { return false }
        return (url.scheme == "https" || url.scheme == "http") && !versionName.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Download Core from URL")
                    .font(.headline)
                
                Spacer()
                
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
            
            // Form content
            Form {
                Section {
                    TextField("Download URL", text: $urlString, prompt: Text("https://example.com/sing-box.tar.gz"))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Source URL")
                } footer: {
                    Text("Enter the direct download URL for the Sing-Box binary archive (.tar.gz or .zip)")
                }
                
                Section {
                    TextField("Version Name", text: $versionName, prompt: Text("1.9.0-custom"))
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Version Label")
                } footer: {
                    Text("A name to identify this version in the list")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supported formats:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            Label(".tar.gz", systemImage: "doc.zipper")
                            Label(".zip", systemImage: "doc.zipper")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Information")
                }
                
                // Download progress
                if coreVersionService.isDownloading {
                    Section {
                        VStack(spacing: 8) {
                            ProgressView(value: coreVersionService.downloadProgress)
                                .progressViewStyle(.linear)
                            
                            Text("\(Int(coreVersionService.downloadProgress * 100))% complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Download Progress")
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    Task {
                        await downloadFromURL()
                    }
                } label: {
                    if coreVersionService.isDownloading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Downloading...")
                        }
                    } else {
                        Text("Download")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidInput || coreVersionService.isDownloading)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 400)
        .onChange(of: urlString) { _, newValue in
            validateURL(newValue)
        }
    }
    
    private func validateURL(_ urlString: String) {
        validationError = nil
        
        guard !urlString.isEmpty else { return }
        
        guard let url = URL(string: urlString) else {
            validationError = "Invalid URL format"
            return
        }
        
        if url.scheme != "https" && url.scheme != "http" {
            validationError = "URL must use https:// or http://"
            return
        }
        
        let path = url.path.lowercased()
        if !path.hasSuffix(".tar.gz") && !path.hasSuffix(".zip") {
            validationError = "URL should point to a .tar.gz or .zip file"
        }
    }
    
    private func downloadFromURL() async {
        guard let url = URL(string: urlString) else { return }
        
        do {
            try await coreVersionService.downloadFromURL(url, versionName: versionName)
            dismiss()
        } catch {
            validationError = error.localizedDescription
        }
    }
}

#Preview {
    DownloadCoreSheet(coreVersionService: {
        let context = ModelContext(SilentXApp.sharedModelContainer)
        return CoreVersionService(modelContext: context)
    }())
}

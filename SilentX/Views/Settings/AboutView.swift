//
//  AboutView.swift
//  SilentX
//
//  About view with app and version information
//

import SwiftUI
import SwiftData

/// View displaying application information and credits
struct AboutView: View {
    @StateObject private var coreVersionService: CoreVersionService
    
    init() {
        let context = ModelContext(SilentXApp.sharedModelContainer)
        _coreVersionService = StateObject(wrappedValue: CoreVersionService(modelContext: context))
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon and Name
            VStack(spacing: 12) {
                Image(systemName: "network")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("SilentX")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("User-Friendly Proxy for macOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .frame(width: 200)
            
            // Version Information
            VStack(spacing: 8) {
                infoRow(label: "App Version", value: "\(appVersion) (\(buildNumber))")
                
                if let activeVersion = coreVersionService.activeVersion {
                    infoRow(label: "Sing-Box Core", value: "v\(activeVersion.version)")
                } else {
                    infoRow(label: "Sing-Box Core", value: "Not installed")
                }
                
                infoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
            }
            
            Divider()
                .frame(width: 200)
            
            // Links
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/SagerNet/sing-box")!) {
                    Label("Sing-Box on GitHub", systemImage: "link")
                }
                
                Link(destination: URL(string: "https://sing-box.sagernet.org")!) {
                    Label("Sing-Box Documentation", systemImage: "book")
                }
                
                Button {
                    // Open support/feedback
                } label: {
                    Label("Send Feedback", systemImage: "envelope")
                }
            }
            
            Spacer()
            
            // Copyright
            VStack(spacing: 4) {
                Text("Powered by Sing-Box")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("© 2024 SilentX. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .frame(width: 250)
    }
}

#Preview {
    AboutView()
}

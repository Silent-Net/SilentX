//
//  ImportProfileSheet.swift
//  SilentX
//
//  Modal sheet for importing profiles from URL or file
//

import SwiftUI
import SwiftData

/// Import profile modal sheet with tabs for different import methods
struct ImportProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ImportURLView(onImport: handleImport)
                    .tabItem {
                        Label("URL", systemImage: "link")
                    }
                    .tag(0)
                
                ImportFileView(onImport: handleImport)
                    .tabItem {
                        Label("File", systemImage: "doc")
                    }
                    .tag(1)
            }
            .padding()
            .navigationTitle("Import Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 350)
    }
    
    private func handleImport(_ profile: Profile) {
        modelContext.insert(profile)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ImportProfileSheet()
        .modelContainer(for: Profile.self, inMemory: true)
}

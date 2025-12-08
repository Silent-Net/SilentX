//
//  EmptyProfilesView.swift
//  SilentX
//
//  Empty state view when no profiles exist, with import guidance
//

import SwiftUI

/// Empty state view with import guidance
struct EmptyProfilesView: View {
    @Binding var showImportSheet: Bool
    
    var body: some View {
        ContentUnavailableView {
            Label("No Profiles", systemImage: "doc.text")
        } description: {
            Text("Import a configuration profile to get started.")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    showImportSheet = true
                } label: {
                    Label("Import Profile", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("Or drag and drop a JSON file here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    EmptyProfilesView(showImportSheet: .constant(false))
}

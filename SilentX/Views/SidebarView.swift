//
//  SidebarView.swift
//  SilentX
//
//  Sidebar navigation view
//

import SwiftUI
import SwiftData

/// Sidebar navigation view with section items
struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @EnvironmentObject var connectionService: ConnectionService
    
    // Appearance settings
    @AppStorage("sidebarIconsOnly") private var sidebarIconsOnly = false
    
    var body: some View {
        List(selection: $selection) {
            // Main navigation section
            Section("Navigation") {
                ForEach(NavigationItem.allCases.filter { $0.isMainSection }) { item in
                    NavigationLink(value: item) {
                        sidebarLabel(for: item)
                    }
                }
            }
            
            // Settings section at bottom
            Section {
                NavigationLink(value: NavigationItem.settings) {
                    sidebarLabel(for: NavigationItem.settings)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: sidebarIconsOnly ? 60 : Constants.sidebarMinWidth,
            ideal: sidebarIconsOnly ? 80 : Constants.sidebarIdealWidth,
            max: sidebarIconsOnly ? 100 : Constants.sidebarMaxWidth
        )
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ConnectionStatusBadge(status: connectionService.status)
            }
        }
    }
    
    /// Create sidebar label with conditional icon-only mode
    @ViewBuilder
    private func sidebarLabel(for item: NavigationItem) -> some View {
        if sidebarIconsOnly {
            Image(systemName: item.systemImage)
                .help(item.rawValue) // Show tooltip on hover
        } else {
            Label(item.rawValue, systemImage: item.systemImage)
        }
    }
}

/// Small badge showing connection status
struct ConnectionStatusBadge: View {
    let status: ConnectionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.shortText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    let context = ModelContext(SilentXApp.sharedModelContainer)
    NavigationSplitView {
        SidebarView(selection: .constant(.dashboard))
            .environmentObject(ConnectionService())
    } detail: {
        Text("Detail View")
    }
}

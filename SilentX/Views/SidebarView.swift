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
    
    var body: some View {
        List(selection: $selection) {
            // Main navigation section
            Section("Navigation") {
                ForEach(NavigationItem.allCases.filter { $0.isMainSection }) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.systemImage)
                    }
                }
            }
            
            // Settings section at bottom
            Section {
                NavigationLink(value: NavigationItem.settings) {
                    Label(NavigationItem.settings.rawValue, systemImage: NavigationItem.settings.systemImage)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: Constants.sidebarMinWidth,
            ideal: Constants.sidebarIdealWidth,
            max: Constants.sidebarMaxWidth
        )
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ConnectionStatusBadge(status: connectionService.status)
            }
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

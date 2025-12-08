//
//  DetailView.swift
//  SilentX
//
//  Detail view router for navigation selection
//

import SwiftUI
import SwiftData

/// Routes to the appropriate detail view based on navigation selection
struct DetailView: View {
    let selection: NavigationItem?
    @EnvironmentObject var connectionService: ConnectionService
    
    var body: some View {
        Group {
            switch selection {
            case .dashboard:
                DashboardView()
                    .environmentObject(connectionService)
            case .profiles:
                ProfileListView()
            case .nodes:
                NodeListView()
            case .rules:
                RuleListView()
            case .logs:
                LogView()
            case .settings:
                SettingsView()
            case .none:
                EmptySelectionView()
            }
        }
    }
}

/// Placeholder view when nothing is selected
struct EmptySelectionView: View {
    var body: some View {
        ContentUnavailableView(
            "Select an Item",
            systemImage: "sidebar.left",
            description: Text("Choose an item from the sidebar to get started.")
        )
    }
}

#Preview {
    DetailView(selection: .dashboard)
        .environmentObject(ConnectionService())
}

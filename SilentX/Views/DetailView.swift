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
    @Binding var navigationSelection: NavigationItem?
    @EnvironmentObject var connectionService: ConnectionService
    @State private var groupsViewModel = GroupsViewModel()
    
    var body: some View {
        Group {
            switch selection {
            case .dashboard:
                DashboardView(onNavigateToProfiles: {
                    navigationSelection = .profiles
                })
                    .environmentObject(connectionService)
            case .groups:
                GroupsView()
                    .environment(groupsViewModel)
                    .environmentObject(connectionService)
            case .profiles:
                ProfileListView()
            case .nodes:
                ConfigNodeListView()  // Use config-based view
            case .rules:
                ConfigRuleListView()  // Use config-based view
            case .logs:
                LogView()
            case .settings:
                SettingsView()
                    .environmentObject(connectionService)
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
    @Previewable @State var selection: NavigationItem? = .dashboard
    DetailView(selection: selection, navigationSelection: $selection)
        .environmentObject(ConnectionService())
}

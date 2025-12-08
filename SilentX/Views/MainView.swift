//
//  MainView.swift
//  SilentX
//
//  Main navigation view with NavigationSplitView
//

import SwiftUI
import SwiftData

/// Main view with NavigationSplitView layout
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: NavigationItem? = .dashboard
    @StateObject private var connectionService: ConnectionService

    init() {
        _connectionService = StateObject(wrappedValue: ConnectionService())
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .environmentObject(connectionService)
        } detail: {
            DetailView(selection: selection)
                .environmentObject(connectionService)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 600)
        .modelContainer(for: [Profile.self, ProxyNode.self, RoutingRule.self, CoreVersion.self], inMemory: true)
}

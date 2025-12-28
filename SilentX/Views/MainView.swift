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
    
    // Auto-connect settings
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    @Query private var allProfiles: [Profile]
    
    // Track if we've already attempted auto-connect
    @State private var hasAttemptedAutoConnect = false

    init() {
        _connectionService = StateObject(wrappedValue: ConnectionService())
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .environmentObject(connectionService)
        } detail: {
            DetailView(selection: selection, navigationSelection: $selection)
                .environmentObject(connectionService)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await attemptAutoConnect()
        }
    }
    
    // MARK: - Auto-Connect
    
    /// Attempt auto-connect on launch if enabled
    private func attemptAutoConnect() async {
        // Only attempt once
        guard !hasAttemptedAutoConnect else { return }
        hasAttemptedAutoConnect = true
        
        // Check if auto-connect is enabled
        guard autoConnectOnLaunch else { return }
        
        // Check if already connected
        if case .connected = connectionService.status { return }
        if case .connecting = connectionService.status { return }
        
        // Find the profile to connect with
        var profile: Profile?
        
        // Try to find stored profile
        if !selectedProfileID.isEmpty {
            profile = allProfiles.first { $0.id.uuidString == selectedProfileID }
        }
        
        // Fall back to first available profile
        if profile == nil {
            profile = allProfiles.first
        }
        
        // Attempt connection
        guard let profileToConnect = profile else { return }
        
        do {
            try await connectionService.connect(profile: profileToConnect)
        } catch {
            print("Auto-connect on launch failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 600)
        .modelContainer(for: [Profile.self, ProxyNode.self, RoutingRule.self, CoreVersion.self], inMemory: true)
}


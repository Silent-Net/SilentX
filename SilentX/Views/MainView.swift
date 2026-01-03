//
//  MainView.swift
//  SilentX
//
//  Main navigation view with NavigationSplitView
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

/// Main view with NavigationSplitView layout
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: NavigationItem? = .dashboard
    
    // Use shared ConnectionService to sync with MenuBar
    private var connectionService: ConnectionService { ConnectionService.shared }
    
    // Auto-connect settings
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    @Query private var allProfiles: [Profile]
    
    // Track if we've already attempted auto-connect
    @State private var hasAttemptedAutoConnect = false
    
    // Pending navigation from MenuBar (shared via AppStorage for reliability)
    @AppStorage("pendingNavigation") private var pendingNavigation: String = ""
    
    // Hide from Dock setting - needed to know when to hide dock on window close
    @AppStorage("hideFromDock") private var hideFromDock = false
    
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
        .onAppear {
            // Check for pending navigation when view appears
            handlePendingNavigation()
        }
        .onChange(of: pendingNavigation) { _, newValue in
            // React immediately when pendingNavigation changes
            handlePendingNavigation()
        }
        #if os(macOS)
        .onDisappear {
            // When window closes, hide from dock if setting is enabled
            if hideFromDock {
                // Delay slightly to ensure all window operations complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Only hide if no other main windows are visible
                    let hasVisibleMainWindow = NSApp.windows.contains { window in
                        window.isVisible && 
                        window.canBecomeKey && 
                        window.level == .normal &&
                        !window.title.contains("Settings")
                    }
                    
                    if !hasVisibleMainWindow {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
        }
        #endif

    }
    
    private func handlePendingNavigation() {
        guard !pendingNavigation.isEmpty else { return }
        
        if pendingNavigation == "Settings" {
            selection = .settings
        } else if let navItem = NavigationItem(rawValue: pendingNavigation) {
            selection = navItem
        }
        
        // Clear pending navigation after handling
        pendingNavigation = ""
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


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
    
    // Window behavior settings
    @AppStorage("hideFromDock") private var hideFromDock = false
    @AppStorage("hideOnClose") private var hideOnClose = true
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
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
        .background(
            // Window close interceptor - hide instead of close when enabled
            WindowCloseInterceptor(
                hideOnClose: hideOnClose && showInMenuBar,
                hideFromDock: hideFromDock
            )
        )
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

// MARK: - Window Close Interceptor

#if os(macOS)
/// Intercepts window close to hide instead of close when "Hide on Close" is enabled
struct WindowCloseInterceptor: NSViewRepresentable {
    let hideOnClose: Bool
    let hideFromDock: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.setupWindowDelegate(for: window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hideOnClose = hideOnClose
        context.coordinator.hideFromDock = hideFromDock
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(hideOnClose: hideOnClose, hideFromDock: hideFromDock)
    }
    
    class Coordinator: NSObject, NSWindowDelegate {
        var hideOnClose: Bool
        var hideFromDock: Bool
        private weak var originalDelegate: NSWindowDelegate?
        private weak var observedWindow: NSWindow?
        
        init(hideOnClose: Bool, hideFromDock: Bool) {
            self.hideOnClose = hideOnClose
            self.hideFromDock = hideFromDock
        }
        
        func setupWindowDelegate(for window: NSWindow) {
            guard observedWindow !== window else { return }
            observedWindow = window
            originalDelegate = window.delegate
            window.delegate = self
        }
        
        // Intercept window close
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if hideOnClose {
                // Hide the window instead of closing
                sender.orderOut(nil)
                
                // Hide from dock if enabled
                if hideFromDock {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let hasVisibleMainWindow = NSApp.windows.contains { window in
                            window.isVisible && 
                            window.canBecomeKey && 
                            window.level == .normal
                        }
                        
                        if !hasVisibleMainWindow {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
                
                return false // Don't close
            }
            
            // Forward to original delegate if exists
            if let original = originalDelegate {
                return original.windowShouldClose?(sender) ?? true
            }
            return true
        }
        
        // Forward other delegate methods
        func windowWillClose(_ notification: Notification) {
            originalDelegate?.windowWillClose?(notification)
        }
        
        func windowDidBecomeKey(_ notification: Notification) {
            originalDelegate?.windowDidBecomeKey?(notification)
        }
        
        func windowDidResignKey(_ notification: Notification) {
            originalDelegate?.windowDidResignKey?(notification)
        }
    }
}
#endif


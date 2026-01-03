//
//  DashboardView.swift
//  SilentX
//
//  Main dashboard view showing connection status and controls
//

import SwiftUI
import SwiftData

/// Main dashboard view with connection controls
struct DashboardView: View {
    @EnvironmentObject var connectionService: ConnectionService
    @Query private var allProfiles: [Profile]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    @AppStorage("proxyMode") private var savedProxyMode: String = "rule"
    
    var onNavigateToProfiles: (() -> Void)? = nil
    
    @State private var selectedProfile: Profile?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var proxyMode: ProxyMode = .rule
    
    private var activeProfile: Profile? {
        selectedProfile
    }
    
    private var isConnected: Bool {
        if case .connected = connectionService.status { return true }
        return false
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection status section
                ConnectionSection(
                    status: connectionService.status,
                    onConnect: handleConnect,
                    onDisconnect: handleDisconnect
                )
                
                // Mode Switcher (only visible when connected)
                if isConnected {
                    ModeSwitcherView(
                        selectedMode: $proxyMode,
                        isConnected: isConnected,
                        onModeChange: handleModeChange
                    )
                    .frame(maxWidth: 400)
                }
                
                // Profile selector
                ProfileSelectorView(
                    selectedProfile: $selectedProfile,
                    onManageProfiles: onNavigateToProfiles
                )
                    .padding(.horizontal)
                
                // System Proxy Controls (only visible when connected)
                if isConnected {
                    SystemProxyControlView()
                        .frame(maxWidth: 400)
                        .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Dashboard")
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Load saved profile on launch (like SFM's SharedPreferences.selectedProfileID)
            loadSavedProfile()
        }
        .onChange(of: selectedProfile) { oldValue, newValue in
            // Save selected profile ID for next launch
            if let profile = newValue {
                selectedProfileID = profile.id.uuidString
                
                // Sync isSelected flag for Profiles page (bidirectional sync)
                for p in allProfiles {
                    p.isSelected = (p.id == profile.id)
                }
                try? modelContext.save()
                
                // Instant switch: if connected and profile changed, restart with new profile immediately
                if oldValue != nil && oldValue?.id != profile.id {
                    if case .connected = connectionService.status {
                        Task {
                            await handleProfileSwitch(to: profile)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedProfileID) { _, newID in
            // Sync when selectedProfileID is changed externally (e.g. from ProfileListView)
            guard !newID.isEmpty,
                  let uuid = UUID(uuidString: newID),
                  selectedProfile?.id != uuid else { return }
            
            if let profile = allProfiles.first(where: { $0.id == uuid }) {
                selectedProfile = profile
            }
        }
    }
    
    // MARK: - Profile Management
    
    /// Handle instant profile switch (disconnect + connect in one smooth operation)
    private func handleProfileSwitch(to profile: Profile) async {
        do {
            // Use restart for cleaner transition
            try await connectionService.disconnect()
            try await connectionService.connect(profile: profile)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func loadSavedProfile() {
        // Skip if profile is already loaded
        guard selectedProfile == nil else { return }
        
        // Restore last selected profile (mimics SFM's SharedPreferences.selectedProfileID.get())
        if !selectedProfileID.isEmpty, let uuid = UUID(uuidString: selectedProfileID) {
            // Find profile with saved ID
            if let savedProfile = allProfiles.first(where: { $0.id == uuid }) {
                selectedProfile = savedProfile
                return
            }
        }
        
        // Fallback: select first profile if saved ID not found
        if let firstProfile = allProfiles.first {
            selectedProfile = firstProfile
            selectedProfileID = firstProfile.id.uuidString
        }
    }
    
    // MARK: - Actions
    
    private func handleConnect() async {
        guard activeProfile != nil else {
            errorMessage = "Please select a profile first"
            showError = true
            return
        }
        
        do {
            if let profile = activeProfile {
                try await connectionService.connect(profile: profile)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleDisconnect() async {
        do {
            try await connectionService.disconnect()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleModeChange(_ mode: ProxyMode) async {
        do {
            try await connectionService.setProxyMode(mode.rawValue)
            savedProxyMode = mode.rawValue
        } catch {
            errorMessage = "Failed to change mode: \(error.localizedDescription)"
            showError = true
        }
    }
}

/// Connection status section with button - Apple Liquid Glass style
struct ConnectionSection: View {
    let status: ConnectionStatus
    let onConnect: () async -> Void
    let onDisconnect: () async -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Large connect button
            ConnectButton(status: status) {
                if status.isConnected {
                    await onDisconnect()
                } else {
                    await onConnect()
                }
            }
            
            // Status indicator
            ConnectionStatusView(status: status)
                .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView()
        .environmentObject(ConnectionService())
        .frame(width: 600, height: 500)
}

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
    
    @State private var selectedProfile: Profile?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    private var activeProfile: Profile? {
        selectedProfile
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connection status section
                ConnectionSection(
                    status: connectionService.status,
                    onConnect: handleConnect,
                    onDisconnect: handleDisconnect
                )
                
                // Profile selector
                ProfileSelectorView(selectedProfile: $selectedProfile)
                    .padding(.horizontal)

                // TODO: Phase 6 - Re-implement statistics tracking
                // Statistics section commented out until statistics tracking is implemented
                // if connectionService.status.isConnected {
                //     StatisticsView(...)
                // }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 32)
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
        .onChange(of: selectedProfile) { _, newValue in
            // Save selected profile ID for next launch
            if let profile = newValue {
                selectedProfileID = profile.id.uuidString
            }
        }
    }
    
    // MARK: - Profile Management
    
    private func loadSavedProfile() {
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
}

/// Connection status section with button
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
    }
}

#Preview {
    DashboardView()
        .environmentObject(ConnectionService())
        .frame(width: 600, height: 500)
}

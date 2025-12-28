//
//  ProxyModeSettingsView.swift
//  SilentX
//
//  Settings view for selecting proxy mode and managing system extension
//

import SwiftUI
import SwiftData

#if os(macOS)
/// View for selecting proxy engine mode and managing system extension
struct ProxyModeSettingsView: View {
    
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allProfiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    
    @State private var extensionInstalled: Bool = false
    @State private var isInstalling: Bool = false
    @State private var isUninstalling: Bool = false
    @State private var showInstallAlert: Bool = false
    @State private var showUninstallAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showModeChangeWarning: Bool = false
    @State private var pendingEngineType: EngineType?
    
    // Service status
    @StateObject private var serviceStatusVM = ServiceStatusViewModel()
    
    @EnvironmentObject private var connectionService: ConnectionService
    
    // Selected profile for mode change
    @Binding var selectedProfile: Profile?
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // Background Service Section
            Section {
                // Status indicator
                HStack {
                    Text("Background Service Status")
                        .font(.headline)
                    
                    Spacer()
                    
                    ServiceStatusBadge(status: serviceStatusVM.status)
                }
                
                // Version display
                if serviceStatusVM.status.isRunning, let version = serviceStatusVM.status.version {
                    HStack {
                        Text("Service Version")
                            .font(.subheadline)
                        Spacer()
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Action buttons
                if !serviceStatusVM.status.isInstalled {
                    // Install button
                    HStack {
                        Text("Install Background Service")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button {
                            Task { await serviceStatusVM.install() }
                        } label: {
                            if serviceStatusVM.isInstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Install")
                            }
                        }
                        .disabled(serviceStatusVM.isInstalling)
                    }
                    
                    Text("Once installed, proxy connections won't require password.\nOnly one admin password during installation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // Reinstall button
                    HStack {
                        Text("Reinstall Service")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button {
                            Task { await serviceStatusVM.reinstall() }
                        } label: {
                            if serviceStatusVM.isInstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Reinstall")
                            }
                        }
                        .disabled(serviceStatusVM.isInstalling || serviceStatusVM.isUninstalling || isConnectedWithHelper)
                    }
                    
                    // Uninstall button
                    HStack {
                        Text("Uninstall Background Service")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            serviceStatusVM.showUninstallConfirmation = true
                        } label: {
                            if serviceStatusVM.isUninstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Uninstall")
                            }
                        }
                        .disabled(serviceStatusVM.isInstalling || serviceStatusVM.isUninstalling || isConnectedWithHelper)
                    }
                    
                    // Warning if connected
                    if isConnectedWithHelper {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Please disconnect before uninstalling service")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Error alerts
                if let error = serviceStatusVM.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Background Service")
            } footer: {
                Text("Recommended: Install once, passwordless forever.\nSame experience as Clash Verge Rev.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Extension Status Section
            Section {
                HStack {
                    Text("System Extension Status")
                        .font(.headline)
                    
                    Spacer()
                    
                    StatusBadge(installed: extensionInstalled)
                }
                
                if !extensionInstalled {
                    HStack {
                        Text("Install System Extension")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button {
                            installExtension()
                        } label: {
                            if isInstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Install")
                            }
                        }
                        .disabled(isInstalling)
                    }
                    
                    Text("Required for System Extension mode.\nNeeds approval in System Preferences after installation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Uninstall System Extension")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            showUninstallAlert = true
                        } label: {
                            if isUninstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Uninstall")
                            }
                        }
                        .disabled(isUninstalling || isConnected)
                    }
                }
            } header: {
                Text("System Extension")
            }
            
            // Engine Mode Selection
            Section {
                if let profile = selectedProfile {
                    Picker(selection: Binding(
                        get: { profile.preferredEngine },
                        set: { newValue in
                            handleEngineChange(to: newValue, for: profile)
                        }
                    )) {
                        ForEach([EngineType.privilegedHelper, EngineType.localProcess, EngineType.networkExtension], id: \.self) { type in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                    Text(type.shortDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                // Availability indicator
                                if type == .privilegedHelper && !serviceStatusVM.status.isInstalled {
                                    Text("Not Installed")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                } else if type == .networkExtension && !extensionInstalled {
                                    Text("Not Installed")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .tag(type)
                        }
                    } label: {
                        Text("Proxy Mode")
                            .font(.headline)
                    }
                    .pickerStyle(.radioGroup)
                    
                    // Warning messages
                    if !serviceStatusVM.status.isInstalled && profile.preferredEngine == .privilegedHelper {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Background service needs to be installed first")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !extensionInstalled && profile.preferredEngine == .networkExtension {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("System extension needs to be installed first")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                } else {
                    Text("Please select a profile first")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Proxy Mode")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background Service (Recommended): Install once, passwordless forever")
                    Text("Local Process: Requires password for each connection")
                    Text("System Extension: Passwordless, uses system VPN")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            await checkExtensionStatus()
        }
        .onAppear {
            serviceStatusVM.startStatusRefresh()
            autoSelectProfileIfNeeded()
        }
        .onDisappear {
            serviceStatusVM.stopStatusRefresh()
        }
        .alert("System Extension", isPresented: $showInstallAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Uninstall System Extension", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                uninstallExtension()
            }
        } message: {
            Text("Are you sure you want to uninstall the system extension? You won't be able to use System Extension mode.")
        }
        .alert("Confirm Uninstall Service", isPresented: $serviceStatusVM.showUninstallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task { await serviceStatusVM.uninstall() }
            }
        } message: {
            Text("After uninstalling the background service, you'll need to enter admin password for each proxy connection.")
        }
        .alert("Switch Proxy Mode", isPresented: $showModeChangeWarning) {
            Button("Cancel", role: .cancel) {
                pendingEngineType = nil
            }
            Button("Disconnect and Switch") {
                Task {
                    try? await connectionService.disconnect()
                    applyEngineChange()
                }
            }
        } message: {
            Text("Currently connected. Switching mode requires disconnection.\nDisconnect and switch to new mode?")
        }
    }
    
    // MARK: - Helper Views
    
    private var isConnected: Bool {
        if case .connected = connectionService.status {
            return true
        }
        return false
    }
    
    private var isConnectedWithHelper: Bool {
        guard case .connected(let info) = connectionService.status else {
            return false
        }
        return info.engineType == .privilegedHelper
    }
    
    // MARK: - Methods
    
    private func checkExtensionStatus() async {
        extensionInstalled = await SystemExtension.isInstalled()
    }
    
    private func installExtension() {
        isInstalling = true
        Task {
            do {
                try await NetworkExtensionEngine.installExtension()
                await checkExtensionStatus()
                alertMessage = extensionInstalled
                    ? "System extension installed successfully!"
                    : "Please approve SilentX extension in System Preferences > Privacy & Security."
            } catch {
                alertMessage = "Installation failed: \(error.localizedDescription)"
            }
            isInstalling = false
            showInstallAlert = true
        }
    }
    
    private func uninstallExtension() {
        isUninstalling = true
        Task {
            do {
                try await NetworkExtensionEngine.uninstallExtension()
                await checkExtensionStatus()
                
                if let profile = selectedProfile, profile.preferredEngine == .networkExtension {
                    profile.preferredEngine = .localProcess
                    try? modelContext.save()
                }
            } catch {
                alertMessage = "Uninstallation failed: \(error.localizedDescription)"
                showInstallAlert = true
            }
            isUninstalling = false
        }
    }
    
    private func handleEngineChange(to newType: EngineType, for profile: Profile) {
        if newType == .privilegedHelper && !serviceStatusVM.status.isInstalled {
            alertMessage = "Please install the background service first"
            showInstallAlert = true
            return
        }
        
        if newType == .networkExtension && !extensionInstalled {
            alertMessage = "Please install the system extension first"
            showInstallAlert = true
            return
        }
        
        if isConnected {
            pendingEngineType = newType
            showModeChangeWarning = true
            return
        }
        
        profile.preferredEngine = newType
        try? modelContext.save()
    }
    
    private func applyEngineChange() {
        guard let newType = pendingEngineType, let profile = selectedProfile else { return }
        profile.preferredEngine = newType
        try? modelContext.save()
        pendingEngineType = nil
    }
    
    /// Auto-select a profile if none is currently selected
    private func autoSelectProfileIfNeeded() {
        // Skip if profile is already selected
        guard selectedProfile == nil else { return }
        
        // Guard against empty profile list
        guard !allProfiles.isEmpty else { return }
        
        // Try to find profile matching stored ID
        if !selectedProfileID.isEmpty,
           let stored = allProfiles.first(where: { $0.id.uuidString == selectedProfileID }) {
            selectedProfile = stored
            return
        }
        
        // Fall back to first available profile
        selectedProfile = allProfiles.first
        
        // Update stored ID if we selected a profile
        if let profile = selectedProfile {
            selectedProfileID = profile.id.uuidString
        }
    }
}

// MARK: - Service Status Badge

private struct ServiceStatusBadge: View {
    let status: ServiceStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(status.isInstalled ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var statusColor: Color {
        if !status.isInstalled {
            return .gray
        } else if status.isRunning {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if !status.isInstalled {
            return "Not Installed"
        } else if status.isRunning {
            return "Running"
        } else {
            return "Stopped"
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let installed: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(installed ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(installed ? "Installed" : "Not Installed")
                .font(.caption)
                .foregroundStyle(installed ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(installed ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    ProxyModeSettingsView(selectedProfile: .constant(nil))
        .environmentObject(ConnectionService())
}
#endif

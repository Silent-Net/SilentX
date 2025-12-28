//
//  ServiceStatusView.swift
//  SilentX
//
//  View for displaying privileged helper service status
//

import SwiftUI
import Combine

/// View that displays the current status of the privileged helper service
struct ServiceStatusView: View {
    let status: ServiceStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator circle
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Background Service")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(status.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Version badge if running
            if status.isRunning, let version = status.version {
                Text("v\(version)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch status.statusColor {
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Extended ServiceStatusView with actions

/// Extended view with install/uninstall buttons
struct ServiceStatusDetailView: View {
    @ObservedObject var viewModel: ServiceStatusViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status section
            ServiceStatusView(status: viewModel.status)
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                if !viewModel.status.isInstalled {
                    // Install button
                    Button(action: {
                        Task { await viewModel.install() }
                    }) {
                        HStack {
                            if viewModel.isInstalling {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text("Install Service")
                        }
                    }
                    .disabled(viewModel.isInstalling || viewModel.isUninstalling)
                } else {
                    // Reinstall button
                    Button(action: {
                        Task { await viewModel.reinstall() }
                    }) {
                        HStack {
                            if viewModel.isInstalling {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text("Reinstall")
                        }
                    }
                    .disabled(viewModel.isInstalling || viewModel.isUninstalling)
                    
                    // Uninstall button
                    Button(action: {
                        viewModel.showUninstallConfirmation = true
                    }) {
                        HStack {
                            if viewModel.isUninstalling {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text("Uninstall Service")
                        }
                    }
                    .disabled(viewModel.isInstalling || viewModel.isUninstalling)
                }
            }
            
            // Error message if any
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .alert("Confirm Uninstall", isPresented: $viewModel.showUninstallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task { await viewModel.uninstall() }
            }
        } message: {
            Text("After uninstalling the background service, you will need to enter admin password for each proxy connection.")
        }
        .onAppear {
            viewModel.startStatusRefresh()
        }
        .onDisappear {
            viewModel.stopStatusRefresh()
        }
    }
}

// MARK: - ViewModel

@MainActor
class ServiceStatusViewModel: ObservableObject {
    @Published var status: ServiceStatus
    @Published var isInstalling = false
    @Published var isUninstalling = false
    @Published var errorMessage: String?
    @Published var showUninstallConfirmation = false
    
    private let serviceInstaller = ServiceInstaller.shared
    private var refreshTask: Task<Void, Never>?
    
    init() {
        // Initialize with a default status until we can check
        self.status = ServiceStatus(
            isInstalled: false,
            isRunning: false,
            version: nil,
            plistPath: nil,
            binaryPath: nil
        )
    }
    
    func startStatusRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await refreshStatus()
            
            // Periodic refresh every 5 seconds
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await refreshStatus()
            }
        }
    }
    
    func stopStatusRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    func refreshStatus() async {
        let newStatus = await serviceInstaller.getStatus()
        await MainActor.run {
            self.status = newStatus
        }
    }
    
    func install() async {
        errorMessage = nil
        isInstalling = true
        
        do {
            try await serviceInstaller.install()
            await refreshStatus()
        } catch let error as ServiceInstallerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isInstalling = false
    }
    
    func uninstall() async {
        errorMessage = nil
        isUninstalling = true
        
        do {
            try await serviceInstaller.uninstall()
            await refreshStatus()
        } catch let error as ServiceInstallerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUninstalling = false
    }
    
    func reinstall() async {
        errorMessage = nil
        isInstalling = true
        
        do {
            // Uninstall first (ignore errors if not installed)
            try? await serviceInstaller.uninstall()
            try await Task.sleep(nanoseconds: 500_000_000) // Brief pause
            try await serviceInstaller.install()
            await refreshStatus()
        } catch let error as ServiceInstallerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isInstalling = false
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ServiceStatusView(status: ServiceStatus(
            isInstalled: true,
            isRunning: true,
            version: "1.0.0",
            plistPath: nil,
            binaryPath: nil
        ))
        
        ServiceStatusView(status: ServiceStatus(
            isInstalled: true,
            isRunning: false,
            version: nil,
            plistPath: nil,
            binaryPath: nil
        ))
        
        ServiceStatusView(status: ServiceStatus(
            isInstalled: false,
            isRunning: false,
            version: nil,
            plistPath: nil,
            binaryPath: nil
        ))
    }
    .padding()
}

//
//  GroupsView.swift
//  SilentX
//
//  Main groups panel showing proxy groups and nodes
//

import SwiftUI

struct GroupsView: View {
    @Environment(GroupsViewModel.self) private var viewModel
    @EnvironmentObject private var connectionService: ConnectionService
    
    var body: some View {
        Group {
            if !isConnected {
                disconnectedView
            } else if viewModel.isLoading && viewModel.groups.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.groups.isEmpty {
                errorView(error)
            } else if viewModel.groups.isEmpty {
                emptyView
            } else {
                groupsContent
            }
        }
        .navigationTitle("Groups")
        .task {
            await loadIfNeeded()
        }
        .onChange(of: connectionService.status) { _, newStatus in
            Task {
                await handleConnectionChange(newStatus)
            }
        }
    }
    
    private var isConnected: Bool {
        if case .connected = connectionService.status {
            return true
        }
        return false
    }
    
    // MARK: - Content Views
    
    private var groupsContent: some View {
        HSplitView {
            // Left: Group list
            GroupListView()
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
            
            // Right: Group detail
            // Pass groupId so GroupDetailView always reads fresh data from viewModel
            if let group = viewModel.selectedGroup {
                GroupDetailView(groupId: group.id)
                    .frame(minWidth: 400)
            } else {
                selectGroupPrompt
            }
        }
    }
    
    private var selectGroupPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a proxy group")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - State Views
    
    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Please connect first")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Connect to proxy to view and manage groups")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading proxy groups...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Loading failed")
                .font(.title2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Proxy Groups")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No proxy groups available in current configuration")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadIfNeeded() async {
        guard isConnected else { return }
        
        // ClashAPIClient is already configured with correct port by ConnectionService.connect()
        // Just pass the config path for parsing groups in correct order
        await viewModel.configure(
            configPath: connectionService.activeConfigPath
        )
    }
    
    private func handleConnectionChange(_ status: ConnectionStatus) async {
        switch status {
        case .connected:
            // ClashAPIClient already configured by ConnectionService
            await viewModel.configure(
                configPath: connectionService.activeConfigPath
            )
        case .disconnected, .error:
            viewModel.clear()
        default:
            break
        }
    }
}

#Preview {
    GroupsView()
        .environment(GroupsViewModel())
        .environmentObject(ConnectionService())
        .frame(width: 800, height: 600)
}

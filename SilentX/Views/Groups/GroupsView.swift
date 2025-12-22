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
            Text("选择一个代理组")
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
            Text("请先连接代理")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("连接代理后即可查看和管理代理组")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在加载代理组...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("加载失败")
                .font(.title2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("重试") {
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
            Text("没有代理组")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("当前配置没有可用的代理组")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadIfNeeded() async {
        guard isConnected else { return }
        
        // Configure Clash API with port and active config path
        // Config path is used to parse groups in correct order
        await viewModel.configure(
            port: ClashAPIClient.defaultPort,
            configPath: connectionService.activeConfigPath
        )
    }
    
    private func handleConnectionChange(_ status: ConnectionStatus) async {
        switch status {
        case .connected:
            await viewModel.configure(
                port: ClashAPIClient.defaultPort,
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

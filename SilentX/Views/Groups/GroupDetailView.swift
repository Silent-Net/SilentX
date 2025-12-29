//
//  GroupDetailView.swift
//  SilentX
//
//  Right panel showing nodes in a proxy group
//

import SwiftUI

struct GroupDetailView: View {
    @Environment(GroupsViewModel.self) private var viewModel
    
    /// The group ID to display (use viewModel.selectedGroup for actual data)
    let groupId: String
    
    @State private var searchText = ""
    
    /// Get the current group from viewModel to ensure we always have fresh data
    private var group: OutboundGroup? {
        viewModel.groups.first { $0.id == groupId }
    }
    
    var body: some View {
        if let group = group {
            VStack(spacing: 0) {
                // Header
                headerView(for: group)
                
                Divider()
                
                // Node list
                if filteredItems(for: group).isEmpty {
                    emptySearchView
                } else {
                    nodeListView(for: group)
                }
            }
        } else {
            Text("Group not found")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Header
    
    private func headerView(for group: OutboundGroup) -> some View {
        HStack(spacing: 12) {
            // Group info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: group.typeIcon)
                        .foregroundStyle(.blue)
                    Text(group.tag)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Compact subtitle: just type and count
                HStack(spacing: 6) {
                    Text(group.typeDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.tertiary)
                    
                    Text("\(group.items.count) nodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !group.selected.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text(group.selected)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search nodes", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 120)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            // Test latency button
            Button {
                Task {
                    await viewModel.testLatency(for: group)
                }
            } label: {
                HStack(spacing: 4) {
                    if viewModel.isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text("Speed Test")
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isTesting)
            .help("Test latency for all nodes")
        }
        .padding()
    }
    
    // MARK: - Node List
    
    private func nodeListView(for group: OutboundGroup) -> some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredItems(for: group)) { item in
                    // Capture groupId to always get fresh group from viewModel
                    let currentGroupId = group.id
                    GroupItemView(
                        item: item,
                        isSelectable: group.isSelectable
                    ) {
                        Task {
                            // Get fresh group reference from viewModel
                            if let freshGroup = viewModel.groups.first(where: { $0.id == currentGroupId }) {
                                await viewModel.selectNode(in: freshGroup, node: item)
                            }
                        }
                    } onTestLatency: {
                        Task {
                            // Get fresh group reference from viewModel
                            if let freshGroup = viewModel.groups.first(where: { $0.id == currentGroupId }) {
                                await viewModel.testLatency(for: item, in: freshGroup)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No matching nodes found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func filteredItems(for group: OutboundGroup) -> [OutboundGroupItem] {
        if searchText.isEmpty {
            return group.items
        }
        return group.items.filter { item in
            item.tag.localizedCaseInsensitiveContains(searchText) ||
            item.type.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    let viewModel = GroupsViewModel()
    // Set up preview data
    return Text("Preview requires GroupsViewModel setup")
        .environment(viewModel)
        .frame(width: 500, height: 400)
}

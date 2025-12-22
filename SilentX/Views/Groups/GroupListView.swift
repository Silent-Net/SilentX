//
//  GroupListView.swift
//  SilentX
//
//  Left sidebar showing list of proxy groups
//

import SwiftUI

struct GroupListView: View {
    @Environment(GroupsViewModel.self) private var viewModel
    
    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedGroup },
            set: { viewModel.selectedGroup = $0 }
        )) {
            ForEach(viewModel.groups) { group in
                GroupRowView(group: group)
                    .tag(group)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新")
                .disabled(viewModel.isLoading)
            }
        }
    }
}

struct GroupRowView: View {
    let group: OutboundGroup
    
    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: group.typeIcon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                // Group name
                Text(group.tag)
                    .font(.headline)
                    .lineLimit(1)
                
                // Type and count
                HStack(spacing: 6) {
                    Text(group.typeDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.tertiary)
                    
                    Text("\(group.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Selected node indicator
            if !group.selected.isEmpty {
                Text(truncatedSelected)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconColor: Color {
        switch group.type.lowercased() {
        case "selector":
            return .blue
        case "urltest":
            return .green
        case "fallback":
            return .orange
        default:
            return .secondary
        }
    }
    
    private var truncatedSelected: String {
        let selected = group.selected
        if selected.count > 8 {
            return String(selected.prefix(6)) + "..."
        }
        return selected
    }
}

#Preview {
    GroupListView()
        .environment(GroupsViewModel())
        .frame(width: 250, height: 400)
}

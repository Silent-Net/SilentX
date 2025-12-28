//
//  ConfigNodeListView.swift
//  SilentX
//
//  Displays proxy nodes parsed directly from the selected profile's sing-box JSON config
//

import SwiftUI
import SwiftData

/// Represents a node parsed from sing-box config JSON
struct ConfigNode: Identifiable, Hashable {
    let id: String  // tag
    let tag: String
    let type: String
    let server: String
    let port: Int
    
    var serverDisplay: String {
        guard !server.isEmpty else { return "—" }
        return "\(server):\(port)"
    }
    
    var protocolIcon: String {
        switch type.lowercased() {
        case "trojan": return "lock.shield"
        case "vmess", "vless": return "v.circle"
        case "shadowsocks", "ss": return "s.circle"
        case "hysteria", "hysteria2": return "hare"
        case "http", "socks", "socks5": return "network"
        case "direct": return "arrow.right"
        case "block", "reject": return "xmark.circle"
        case "selector", "urltest": return "list.bullet"
        default: return "server.rack"
        }
    }
    
    var isBuiltIn: Bool {
        ["direct", "block", "dns", "selector", "urltest"].contains(type.lowercased())
    }
}

/// Node list view that reads from selected profile's configurationJSON
struct ConfigNodeListView: View {
    @Query private var allProfiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    
    @State private var nodes: [ConfigNode] = []
    @State private var showBuiltIn = false
    @State private var searchText = ""
    
    private var selectedProfile: Profile? {
        if !selectedProfileID.isEmpty, let uuid = UUID(uuidString: selectedProfileID) {
            return allProfiles.first { $0.id == uuid }
        }
        return allProfiles.first
    }
    
    private var filteredNodes: [ConfigNode] {
        var result = nodes
        
        // Filter built-in nodes
        if !showBuiltIn {
            result = result.filter { !$0.isBuiltIn }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { node in
                node.tag.localizedCaseInsensitiveContains(searchText) ||
                node.server.localizedCaseInsensitiveContains(searchText) ||
                node.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        Group {
            if selectedProfile == nil {
                ContentUnavailableView {
                    Label("No Profile Selected", systemImage: "doc.questionmark")
                } description: {
                    Text("Select a profile in the Dashboard to view its nodes.")
                }
            } else if nodes.isEmpty {
                ContentUnavailableView {
                    Label("No Nodes", systemImage: "server.rack")
                } description: {
                    Text("This profile doesn't contain any outbound nodes.")
                }
            } else if filteredNodes.isEmpty {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "magnifyingglass")
                } description: {
                    Text("No nodes match your search.")
                }
            } else {
                nodeList
            }
        }
        .navigationTitle("Proxy Nodes")
        .searchable(text: $searchText, prompt: "Search nodes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $showBuiltIn) {
                    Label("Show Built-in", systemImage: "eye")
                }
                .help("Show built-in nodes (direct, block, selector, etc.)")
                
                Text("\(filteredNodes.count) nodes")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .onAppear {
            parseNodes()
        }
        .onChange(of: selectedProfileID) { _, _ in
            parseNodes()
        }
    }
    
    private var nodeList: some View {
        List {
            ForEach(filteredNodes) { node in
                ConfigNodeRowView(node: node)
            }
        }
        .listStyle(.inset)
    }
    
    private func parseNodes() {
        guard let profile = selectedProfile else {
            nodes = []
            return
        }
        
        guard let data = profile.configurationJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = json["outbounds"] as? [[String: Any]] else {
            nodes = []
            return
        }
        
        var parsedNodes: [ConfigNode] = []
        
        for outbound in outbounds {
            guard let tag = outbound["tag"] as? String,
                  let type = outbound["type"] as? String else {
                continue
            }
            
            let server = outbound["server"] as? String ?? ""
            let port = outbound["server_port"] as? Int ?? 0
            
            parsedNodes.append(ConfigNode(
                id: tag,
                tag: tag,
                type: type,
                server: server,
                port: port
            ))
        }
        
        nodes = parsedNodes
    }
}

/// Row view for a config node
struct ConfigNodeRowView: View {
    let node: ConfigNode
    
    var body: some View {
        HStack(spacing: 12) {
            // Node info
            VStack(alignment: .leading, spacing: 4) {
                Text(node.tag)
                    .font(.headline)
                    .foregroundStyle(node.isBuiltIn ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    Text(node.type.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.15))
                        .foregroundStyle(typeColor)
                        .cornerRadius(4)
                    
                    if !node.server.isEmpty {
                        Text(node.serverDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var typeColor: Color {
        switch node.type.lowercased() {
        case "trojan": return .purple
        case "vmess", "vless": return .blue
        case "shadowsocks", "ss": return .green
        case "hysteria", "hysteria2": return .orange
        case "direct": return .gray
        case "block", "reject": return .red
        case "selector", "urltest": return .teal
        default: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        ConfigNodeListView()
    }
    .modelContainer(for: Profile.self, inMemory: true)
}

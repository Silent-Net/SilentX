//
//  DetailView.swift
//  SilentX
//
//  Detail view router for navigation selection
//

import SwiftUI
import SwiftData

/// Routes to the appropriate detail view based on navigation selection
struct DetailView: View {
    let selection: NavigationItem?
    @Binding var navigationSelection: NavigationItem?
    @EnvironmentObject var connectionService: ConnectionService
    @State private var groupsViewModel = GroupsViewModel()
    
    // Preloaded data for instant panel switching
    @State private var preloadedNodes: [ConfigNode] = []
    @State private var preloadedRules: [ConfigRule] = []
    @State private var preloadedRulesFinal: String = ""
    @State private var lastPreloadedProfileID: String = ""
    
    var body: some View {
        // Use .id() modifier to control view identity
        // This prevents view recreation when same panel is selected
        Group {
            switch selection {
            case .dashboard:
                DashboardView(onNavigateToProfiles: {
                    navigationSelection = .profiles
                })
                    .environmentObject(connectionService)
            case .groups:
                GroupsView()
                    .environment(groupsViewModel)
                    .environmentObject(connectionService)
            case .profiles:
                ProfileListView()
            case .nodes:
                ConfigNodeListView(preloadedNodes: preloadedNodes)
            case .rules:
                ConfigRuleListView(preloadedRules: preloadedRules, preloadedFinal: preloadedRulesFinal)
            case .logs:
                LogView()
            case .settings:
                SettingsView()
                    .environmentObject(connectionService)
            case .none:
                EmptySelectionView()
            }
        }
        .id(selection) // Apple's recommended approach: use .id() for view identity
        // Preload data when connection establishes - NOT when panels switch
        // Only preload from local config file, NOT network calls
        .onChange(of: connectionService.status) { _, newStatus in
            if case .connected = newStatus {
                // Preload in background with delay to ensure UI is responsive
                Task {
                    // Small delay to let UI settle first
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    await preloadNodesAndRules()
                }
            }
        }
    }
    
    /// Preload nodes and rules from local config (no network calls)
    
    @MainActor
    private func preloadNodesAndRules() async {
        guard let configPath = connectionService.activeConfigPath else { return }
        
        let profileID = configPath.lastPathComponent
        guard lastPreloadedProfileID != profileID else { return }
        
        // Parse in background
        let result = await Task.detached(priority: .utility) { () -> (nodes: [ConfigNode], rules: [ConfigRule], final: String) in
            guard let data = try? Data(contentsOf: configPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ([], [], "")
            }
            
            // Parse nodes
            var nodes: [ConfigNode] = []
            if let outbounds = json["outbounds"] as? [[String: Any]] {
                for outbound in outbounds {
                    guard let tag = outbound["tag"] as? String,
                          let type = outbound["type"] as? String else { continue }
                    let server = outbound["server"] as? String ?? ""
                    let port = outbound["server_port"] as? Int ?? 0
                    nodes.append(ConfigNode(id: tag, tag: tag, type: type, server: server, port: port))
                }
            }
            
            // Parse rules
            var rules: [ConfigRule] = []
            var finalOutbound = "direct"
            if let route = json["route"] as? [String: Any] {
                finalOutbound = route["final"] as? String ?? "direct"
                if let rulesList = route["rules"] as? [[String: Any]] {
                    for rule in rulesList {
                        let outbound = rule["outbound"] as? String ?? ""
                        let action = rule["action"] as? String ?? ""
                        let targetOutbound = outbound.isEmpty ? action : outbound
                        let isAction = outbound.isEmpty && !action.isEmpty
                        
                        let matchTypes = ["domain", "domain_suffix", "domain_keyword", "geosite", "geoip", "ip_cidr", "rule_set", "process_name", "network", "port"]
                        for matchType in matchTypes {
                            if let value = rule[matchType] {
                                let matchValue: String
                                if let s = value as? String { matchValue = s }
                                else if let arr = value as? [String] { matchValue = arr.prefix(2).joined(separator: ", ") + (arr.count > 2 ? "..." : "") }
                                else { continue }
                                rules.append(ConfigRule(matchType: matchType, matchValue: matchValue, outbound: targetOutbound, isAction: isAction))
                                break
                            }
                        }
                    }
                }
            }
            
            return (nodes, rules, finalOutbound)
        }.value
        
        preloadedNodes = result.nodes
        preloadedRules = result.rules
        preloadedRulesFinal = result.final
        lastPreloadedProfileID = profileID
    }
}

/// Placeholder view when nothing is selected
struct EmptySelectionView: View {
    var body: some View {
        ContentUnavailableView(
            "Select an Item",
            systemImage: "sidebar.left",
            description: Text("Choose an item from the sidebar to get started.")
        )
    }
}

#Preview {
    @Previewable @State var selection: NavigationItem? = .dashboard
    DetailView(selection: selection, navigationSelection: $selection)
        .environmentObject(ConnectionService())
}

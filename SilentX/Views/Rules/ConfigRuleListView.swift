//
//  ConfigRuleListView.swift
//  SilentX
//
//  Displays routing rules parsed directly from the selected profile's sing-box JSON config
//

import SwiftUI
import SwiftData

/// Represents a rule parsed from sing-box config JSON
struct ConfigRule: Identifiable, Hashable {
    let id = UUID()
    let matchType: String
    let matchValue: String
    let outbound: String
    let isAction: Bool  // true if it's an action (sniff, hijack-dns, reject) rather than outbound
    
    var displayType: String {
        switch matchType.lowercased() {
        case "domain": return "Domain"
        case "domain_suffix": return "Domain Suffix"
        case "domain_keyword": return "Domain Keyword"
        case "domain_regex": return "Domain Regex"
        case "ip_cidr": return "IP CIDR"
        case "geoip": return "GeoIP"
        case "geosite": return "Geosite"
        case "process_name": return "Process"
        case "process_path": return "Process Path"
        case "rule_set": return "Rule Set"
        case "protocol": return "Protocol"
        case "network": return "Network"
        case "port": return "Port"
        case "ip_is_private": return "Private IP"
        case "clash_mode": return "Clash Mode"
        case "action": return "Action"
        case "type": return "Logical"
        default: return matchType
        }
    }
    
    var typeIcon: String {
        switch matchType.lowercased() {
        case "domain", "domain_suffix", "domain_keyword", "domain_regex": return "globe"
        case "ip_cidr", "ip_is_private": return "network"
        case "geoip": return "location"
        case "geosite", "rule_set": return "list.bullet.rectangle"
        case "process_name", "process_path": return "app"
        case "protocol": return "lock"
        case "network": return "wifi"
        case "port": return "number"
        case "clash_mode": return "switch.2"
        case "action", "type": return "bolt"
        default: return "questionmark.circle"
        }
    }
    
    var outboundColor: Color {
        if isAction {
            switch outbound.lowercased() {
            case "reject": return .red
            case "sniff": return .orange
            case "hijack-dns": return .purple
            default: return .blue
            }
        }
        
        switch outbound.lowercased() {
        case "direct": return .gray
        case let s where s.contains("china") || s.contains("🇨🇳"): return .orange
        case let s where s.contains("america") || s.contains("🇺🇸"): return .blue
        case let s where s.contains("hong kong") || s.contains("🇭🇰"): return .red
        case let s where s.contains("taiwan") || s.contains("🇹🇼"): return .teal
        case let s where s.contains("singapore") || s.contains("🇸🇬"): return .green
        case let s where s.contains("japan") || s.contains("🇯🇵"): return .pink
        default: return .primary
        }
    }
}

/// Rule list view that reads from selected profile's configurationJSON
struct ConfigRuleListView: View {
    @Query private var allProfiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    
    @State private var rules: [ConfigRule] = []
    @State private var searchText = ""
    @State private var finalOutbound: String = ""
    
    private var selectedProfile: Profile? {
        if !selectedProfileID.isEmpty, let uuid = UUID(uuidString: selectedProfileID) {
            return allProfiles.first { $0.id == uuid }
        }
        return allProfiles.first
    }
    
    private var filteredRules: [ConfigRule] {
        guard !searchText.isEmpty else { return rules }
        return rules.filter { rule in
            rule.matchType.localizedCaseInsensitiveContains(searchText) ||
            rule.matchValue.localizedCaseInsensitiveContains(searchText) ||
            rule.outbound.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if selectedProfile == nil {
                ContentUnavailableView {
                    Label("No Profile Selected", systemImage: "doc.questionmark")
                } description: {
                    Text("Select a profile in the Dashboard to view its rules.")
                }
            } else if rules.isEmpty {
                ContentUnavailableView {
                    Label("No Rules", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("This profile doesn't contain any routing rules.")
                }
            } else if filteredRules.isEmpty {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "magnifyingglass")
                } description: {
                    Text("No rules match your search.")
                }
            } else {
                ruleList
            }
        }
        .navigationTitle("Routing Rules")
        .navigationSubtitle(finalOutbound.isEmpty ? "\(filteredRules.count) rules" : "\(filteredRules.count) rules · Final: \(finalOutbound)")
        .searchable(text: $searchText, prompt: "Search rules")
        .onAppear {
            parseRules()
        }
        .onChange(of: selectedProfileID) { _, _ in
            parseRules()
        }
    }
    
    private var ruleList: some View {
        List {
            ForEach(Array(filteredRules.enumerated()), id: \.element.id) { index, rule in
                ConfigRuleRowView(rule: rule, index: index + 1)
            }
        }
        .listStyle(.inset)
    }
    
    private func parseRules() {
        guard let profile = selectedProfile else {
            rules = []
            finalOutbound = ""
            return
        }
        
        guard let data = profile.configurationJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let route = json["route"] as? [String: Any],
              let rulesList = route["rules"] as? [[String: Any]] else {
            rules = []
            finalOutbound = ""
            return
        }
        
        // Get final outbound
        finalOutbound = route["final"] as? String ?? "direct"
        
        var parsedRules: [ConfigRule] = []
        
        for rule in rulesList {
            // Determine outbound or action
            let outbound = rule["outbound"] as? String ?? ""
            let action = rule["action"] as? String ?? ""
            let targetOutbound = outbound.isEmpty ? action : outbound
            let isAction = outbound.isEmpty && !action.isEmpty
            
            // Find match type and value
            let matchTypes = [
                "domain", "domain_suffix", "domain_keyword", "domain_regex",
                "ip_cidr", "geoip", "geosite", "process_name", "process_path",
                "rule_set", "protocol", "network", "port", "ip_is_private",
                "clash_mode", "type"
            ]
            
            var foundMatch = false
            
            for matchType in matchTypes {
                if let value = rule[matchType] {
                    let matchValue: String
                    
                    if let stringValue = value as? String {
                        matchValue = stringValue
                    } else if let arrayValue = value as? [String] {
                        matchValue = arrayValue.prefix(3).joined(separator: ", ") + (arrayValue.count > 3 ? "... +\(arrayValue.count - 3)" : "")
                    } else if let boolValue = value as? Bool {
                        matchValue = boolValue ? "true" : "false"
                    } else if let intValue = value as? Int {
                        matchValue = String(intValue)
                    } else {
                        continue
                    }
                    
                    parsedRules.append(ConfigRule(
                        matchType: matchType,
                        matchValue: matchValue,
                        outbound: targetOutbound,
                        isAction: isAction
                    ))
                    foundMatch = true
                    break
                }
            }
            
            // If no match type found but has action, add it as action rule
            if !foundMatch && isAction {
                parsedRules.append(ConfigRule(
                    matchType: "action",
                    matchValue: action,
                    outbound: action,
                    isAction: true
                ))
            }
        }
        
        rules = parsedRules
    }
}

/// Row view for a config rule
struct ConfigRuleRowView: View {
    let rule: ConfigRule
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Index badge
            Text("\(index)")
                .font(.caption2)
                .fontWeight(.medium)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            
            // Type icon
            Image(systemName: rule.typeIcon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // Rule info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(rule.displayType)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    if !rule.matchValue.isEmpty && rule.matchType != "action" {
                        Text(rule.matchValue)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                
                // Outbound
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(rule.outbound)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(rule.outboundColor)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ConfigRuleListView()
    }
    .modelContainer(for: Profile.self, inMemory: true)
}

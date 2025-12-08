//
//  RuleRowView.swift
//  SilentX
//
//  Row view for displaying a routing rule in the list
//

import SwiftUI

/// Row view for a single routing rule in the list
struct RuleRowView: View {
    let rule: RoutingRule
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Text("#\(rule.priority + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30)
            
            // Match type icon
            matchTypeIcon
            
            // Rule info
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.matchValue)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(rule.matchType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Action badge
            actionBadge
        }
        .padding(.vertical, 4)
    }
    
    private var matchTypeIcon: some View {
        ZStack {
            Circle()
                .fill(rule.matchType.color.opacity(0.2))
                .frame(width: 36, height: 36)
            
            Image(systemName: rule.matchType.iconName)
                .font(.system(size: 14))
                .foregroundStyle(rule.matchType.color)
        }
    }
    
    private var actionBadge: some View {
        Text(rule.action.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(rule.action.color)
            .clipShape(Capsule())
    }
}

// MARK: - Match Type Extensions (UI-specific)

extension RuleMatchType {
    var iconName: String {
        switch self {
        case .domain: return "globe"
        case .domainSuffix: return "globe.americas"
        case .domainKeyword: return "magnifyingglass"
        case .ipCIDR: return "number"
        case .geoIP: return "map"
        case .process: return "app.badge"
        }
    }
    
    var color: Color {
        switch self {
        case .domain: return .blue
        case .domainSuffix: return .cyan
        case .domainKeyword: return .purple
        case .ipCIDR: return .orange
        case .geoIP: return .green
        case .process: return .pink
        }
    }
    
    var helpText: String {
        switch self {
        case .domain: return "Exact domain match"
        case .domainSuffix: return "Match domains ending with this suffix"
        case .domainKeyword: return "Match domains containing this keyword"
        case .ipCIDR: return "Match IP addresses in CIDR notation"
        case .geoIP: return "Match by country code (e.g., CN, US)"
        case .process: return "Match by application name"
        }
    }
}

// MARK: - Rule Action Extensions (UI-specific)

extension RuleAction {
    // displayName is already defined in RuleAction.swift
    // No duplicate needed here
}

#Preview {
    List {
        RuleRowView(rule: {
            let rule = RoutingRule(
                matchType: .domainSuffix,
                matchValue: ".google.com",
                action: .proxy
            )
            rule.priority = 0
            return rule
        }())
        
        RuleRowView(rule: {
            let rule = RoutingRule(
                matchType: .geoIP,
                matchValue: "CN",
                action: .direct
            )
            rule.priority = 1
            return rule
        }())
        
        RuleRowView(rule: {
            let rule = RoutingRule(
                matchType: .domain,
                matchValue: "ads.example.com",
                action: .block
            )
            rule.priority = 2
            return rule
        }())
    }
}

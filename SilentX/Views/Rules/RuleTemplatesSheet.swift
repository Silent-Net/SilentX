//
//  RuleTemplatesSheet.swift
//  SilentX
//
//  Sheet view for selecting from common rule templates
//

import SwiftUI
import SwiftData

/// Rule template definition
struct RuleTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let rules: [TemplateRule]
    let category: TemplateCategory
    
    enum TemplateCategory: String, CaseIterable {
        case regional = "Regional"
        case streaming = "Streaming"
        case privacy = "Privacy"
        case gaming = "Gaming"
        case development = "Development"
        
        var iconName: String {
            switch self {
            case .regional: return "globe"
            case .streaming: return "play.tv"
            case .privacy: return "hand.raised"
            case .gaming: return "gamecontroller"
            case .development: return "hammer"
            }
        }
    }
}

/// Individual rule in a template
struct TemplateRule {
    let matchType: RuleMatchType
    let matchValue: String
    let action: RuleAction
}

/// Sheet for selecting rule templates
struct RuleTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutingRule.priority) private var existingRules: [RoutingRule]
    
    @State private var selectedCategory: RuleTemplate.TemplateCategory = .regional
    @State private var successMessage: String?
    @State private var showSuccess = false
    
    private let templates = RuleTemplatesSheet.defaultTemplates
    
    var body: some View {
        NavigationStack {
            HSplitView {
                // Category sidebar
                List(RuleTemplate.TemplateCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                    Label(category.rawValue, systemImage: category.iconName)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 150, idealWidth: 180)
                
                // Templates list
                List {
                    ForEach(templates.filter { $0.category == selectedCategory }) { template in
                        templateRow(template)
                    }
                }
                .listStyle(.inset)
            }
            .navigationTitle("Rule Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Rules Added", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "Template rules have been added")
        }
    }
    
    private func templateRow(_ template: RuleTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Add") {
                    addTemplate(template)
                }
                .buttonStyle(.bordered)
            }
            
            // Preview of rules
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(template.rules.prefix(5), id: \.matchValue) { rule in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(rule.action.color)
                                .frame(width: 6, height: 6)
                            Text(rule.matchValue)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    if template.rules.count > 5 {
                        Text("+\(template.rules.count - 5) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func addTemplate(_ template: RuleTemplate) {
        var currentPriority = existingRules.count
        
        for templateRule in template.rules {
            let rule = RoutingRule(
                matchType: templateRule.matchType,
                matchValue: templateRule.matchValue,
                action: templateRule.action
            )
            rule.priority = currentPriority
            currentPriority += 1
            
            modelContext.insert(rule)
        }
        
        do {
            try modelContext.save()
            successMessage = "Added \(template.rules.count) rules from \"\(template.name)\""
            showSuccess = true
        } catch {
            // Handle error silently for now
        }
    }
    
    // MARK: - Default Templates
    
    static let defaultTemplates: [RuleTemplate] = [
        // Regional
        RuleTemplate(
            name: "China Direct",
            description: "Route Chinese websites directly",
            rules: [
                TemplateRule(matchType: .geoIP, matchValue: "CN", action: .direct),
                TemplateRule(matchType: .domainSuffix, matchValue: ".cn", action: .direct),
                TemplateRule(matchType: .domainSuffix, matchValue: ".com.cn", action: .direct),
            ],
            category: .regional
        ),
        RuleTemplate(
            name: "Global Proxy",
            description: "Route international websites through proxy",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".google.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".googleapis.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".youtube.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".twitter.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".facebook.com", action: .proxy),
            ],
            category: .regional
        ),
        
        // Streaming
        RuleTemplate(
            name: "Netflix",
            description: "Route Netflix through proxy for regional access",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".netflix.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".netflix.net", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".nflxvideo.net", action: .proxy),
            ],
            category: .streaming
        ),
        RuleTemplate(
            name: "YouTube",
            description: "Route YouTube through proxy",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".youtube.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".googlevideo.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".ytimg.com", action: .proxy),
            ],
            category: .streaming
        ),
        
        // Privacy
        RuleTemplate(
            name: "Block Ads",
            description: "Block common advertising domains",
            rules: [
                TemplateRule(matchType: .domainKeyword, matchValue: "doubleclick", action: .block),
                TemplateRule(matchType: .domainKeyword, matchValue: "adservice", action: .block),
                TemplateRule(matchType: .domainSuffix, matchValue: ".ads.google.com", action: .block),
                TemplateRule(matchType: .domainSuffix, matchValue: ".ad.doubleclick.net", action: .block),
            ],
            category: .privacy
        ),
        RuleTemplate(
            name: "Block Trackers",
            description: "Block common tracking domains",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".google-analytics.com", action: .block),
                TemplateRule(matchType: .domainSuffix, matchValue: ".hotjar.com", action: .block),
                TemplateRule(matchType: .domainKeyword, matchValue: "analytics", action: .block),
            ],
            category: .privacy
        ),
        
        // Gaming
        RuleTemplate(
            name: "Steam",
            description: "Route Steam through proxy",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".steampowered.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".steamcommunity.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".steamstatic.com", action: .proxy),
            ],
            category: .gaming
        ),
        
        // Development
        RuleTemplate(
            name: "GitHub",
            description: "Route GitHub through proxy",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".github.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".githubusercontent.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".githubassets.com", action: .proxy),
            ],
            category: .development
        ),
        RuleTemplate(
            name: "NPM & Package Managers",
            description: "Route package managers through proxy",
            rules: [
                TemplateRule(matchType: .domainSuffix, matchValue: ".npmjs.org", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".npmjs.com", action: .proxy),
                TemplateRule(matchType: .domainSuffix, matchValue: ".pypi.org", action: .proxy),
            ],
            category: .development
        ),
    ]
}

#Preview {
    RuleTemplatesSheet()
        .modelContainer(for: RoutingRule.self, inMemory: true)
}

//
//  EditRuleSheet.swift
//  SilentX
//
//  Form modal for editing an existing routing rule
//

import SwiftUI
import SwiftData

/// Sheet for editing an existing routing rule
struct EditRuleSheet: View {
    @Bindable var rule: RoutingRule
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var matchType: RuleMatchType = .domain
    @State private var matchValue = ""
    @State private var action: RuleAction = .proxy
    @State private var validationError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // Match type selection
                Section("Match Condition") {
                    Picker("Match Type", selection: $matchType) {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    TextField("Value", text: $matchValue, prompt: Text(matchType.placeholder))
                        .autocorrectionDisabled()
                    
                    Text(matchType.helpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Action selection
                Section("Action") {
                    Picker("Action", selection: $action) {
                        ForEach(RuleAction.allCases, id: \.self) { action in
                            HStack {
                                Circle()
                                    .fill(action.color)
                                    .frame(width: 10, height: 10)
                                Text(action.displayName)
                            }
                            .tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(actionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Validation error
                if let error = validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(matchValue.isEmpty)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 350)
        .onAppear {
            loadRuleData()
        }
    }
    
    private var actionDescription: String {
        switch action {
        case .proxy:
            return "Route traffic through the proxy server"
        case .direct:
            return "Connect directly without proxy"
        case .block:
            return "Block all traffic to this destination"
        }
    }
    
    private func loadRuleData() {
        matchType = rule.matchType
        matchValue = rule.matchValue
        action = rule.action
    }
    
    private func saveRule() {
        // Validate match value based on type
        if let error = validateMatchValue() {
            validationError = error
            return
        }
        
        rule.matchType = matchType
        rule.matchValue = matchValue.trimmingCharacters(in: .whitespaces)
        rule.action = action
        rule.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationError = error.localizedDescription
        }
    }
    
    private func validateMatchValue() -> String? {
        let value = matchValue.trimmingCharacters(in: .whitespaces)
        
        switch matchType {
        case .domain, .domainSuffix:
            let domainPattern = "^\\.?[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
            if value.range(of: domainPattern, options: .regularExpression) == nil {
                return "Invalid domain format"
            }
            
        case .domainKeyword:
            if value.isEmpty {
                return "Keyword cannot be empty"
            }
            
        case .ipCIDR:
            let cidrPattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
            if value.range(of: cidrPattern, options: .regularExpression) == nil {
                return "Invalid CIDR format (e.g., 192.168.1.0/24)"
            }
            
        case .geoIP:
            if value.count != 2 || !value.allSatisfy({ $0.isLetter }) {
                return "Invalid country code (use 2-letter code like CN, US)"
            }
            
        case .process:
            if value.isEmpty {
                return "Process name cannot be empty"
            }
        }
        
        return nil
    }
}

#Preview {
    EditRuleSheet(rule: RoutingRule(
        matchType: .domainSuffix,
        matchValue: ".google.com",
        action: .proxy
    ))
    .modelContainer(for: RoutingRule.self, inMemory: true)
}

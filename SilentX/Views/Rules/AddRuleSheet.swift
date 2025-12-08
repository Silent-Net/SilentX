//
//  AddRuleSheet.swift
//  SilentX
//
//  Form modal for adding a new routing rule
//

import SwiftUI
import SwiftData

/// Sheet for adding a new routing rule
struct AddRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutingRule.priority) private var existingRules: [RoutingRule]
    
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
            .navigationTitle("Add Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRule()
                    }
                    .disabled(matchValue.isEmpty)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 350)
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
    
    private func addRule() {
        // Validate match value based on type
        if let error = validateMatchValue() {
            validationError = error
            return
        }
        
        let rule = RoutingRule(
            matchType: matchType,
            matchValue: matchValue.trimmingCharacters(in: .whitespaces),
            action: action
        )
        
        // Set priority to be after all existing rules
        rule.priority = existingRules.count
        
        modelContext.insert(rule)
        
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
            // Basic domain validation
            let domainPattern = "^\\.?[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
            if value.range(of: domainPattern, options: .regularExpression) == nil {
                return "Invalid domain format"
            }
            
        case .domainKeyword:
            if value.isEmpty {
                return "Keyword cannot be empty"
            }
            
        case .ipCIDR:
            // Basic CIDR validation
            let cidrPattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
            if value.range(of: cidrPattern, options: .regularExpression) == nil {
                return "Invalid CIDR format (e.g., 192.168.1.0/24)"
            }
            
        case .geoIP:
            // Country code should be 2 letters
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
    AddRuleSheet()
        .modelContainer(for: RoutingRule.self, inMemory: true)
}

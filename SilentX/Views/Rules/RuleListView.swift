//
//  RuleListView.swift
//  SilentX
//
//  List view displaying all routing rules with SwiftData @Query
//

import SwiftUI
import SwiftData

/// Main rule list view
struct RuleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutingRule.order) private var rules: [RoutingRule]
    
    @State private var showAddSheet = false
    @State private var showTemplateSheet = false
    @State private var showDeleteAlert = false
    @State private var ruleToDelete: RoutingRule?
    @State private var selectedRule: RoutingRule?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        Group {
            if rules.isEmpty {
                emptyView
            } else {
                ruleList
            }
        }
        .navigationTitle("Routing Rules")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Custom Rule", systemImage: "plus")
                    }
                    
                    Button {
                        showTemplateSheet = true
                    } label: {
                        Label("Add from Template", systemImage: "doc.on.doc")
                    }
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRuleSheet()
        }
        .sheet(isPresented: $showTemplateSheet) {
            RuleTemplatesSheet()
        }
        .sheet(item: $selectedRule) { rule in
            EditRuleSheet(rule: rule)
        }
        .alert("Delete Rule", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let rule = ruleToDelete {
                    deleteRule(rule)
                }
            }
        } message: {
            Text("Are you sure you want to delete this rule?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Rules", systemImage: "arrow.triangle.branch")
        } description: {
            Text("Add routing rules to control traffic flow.")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Custom Rule", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    showTemplateSheet = true
                } label: {
                    Label("Use Template", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var ruleList: some View {
        List {
            ForEach(rules) { rule in
                RuleRowView(rule: rule)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRule = rule
                    }
                    .contextMenu {
                        ruleContextMenu(for: rule)
                    }
            }
            .onDelete(perform: deleteRules)
            .onMove(perform: moveRules)
        }
        .listStyle(.inset)
    }
    
    @ViewBuilder
    private func ruleContextMenu(for rule: RoutingRule) -> some View {
        Button {
            selectedRule = rule
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        
        Divider()
        
        Button {
            duplicateRule(rule)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Button {
            moveRuleUp(rule)
        } label: {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(rule.priority == 0)
        
        Button {
            moveRuleDown(rule)
        } label: {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(rule.priority == rules.count - 1)
        
        Divider()
        
        Button(role: .destructive) {
            ruleToDelete = rule
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
        try? modelContext.save()
        reorderRules()
    }
    
    private func deleteRule(_ rule: RoutingRule) {
        modelContext.delete(rule)
        try? modelContext.save()
        reorderRules()
    }
    
    private func moveRules(from source: IndexSet, to destination: Int) {
        var reorderedRules = rules
        reorderedRules.move(fromOffsets: source, toOffset: destination)
        
        for (index, rule) in reorderedRules.enumerated() {
            rule.priority = index
        }
        
        try? modelContext.save()
    }
    
    private func duplicateRule(_ rule: RoutingRule) {
        let duplicate = RoutingRule(
            matchType: rule.matchType,
            matchValue: rule.matchValue,
            action: rule.action
        )
        duplicate.priority = rules.count
        
        modelContext.insert(duplicate)
        try? modelContext.save()
    }
    
    private func moveRuleUp(_ rule: RoutingRule) {
        guard rule.priority > 0 else { return }
        
        if let swapRule = rules.first(where: { $0.priority == rule.priority - 1 }) {
            swapRule.priority += 1
            rule.priority -= 1
            try? modelContext.save()
        }
    }
    
    private func moveRuleDown(_ rule: RoutingRule) {
        guard rule.priority < rules.count - 1 else { return }
        
        if let swapRule = rules.first(where: { $0.priority == rule.priority + 1 }) {
            swapRule.priority -= 1
            rule.priority += 1
            try? modelContext.save()
        }
    }
    
    private func reorderRules() {
        let sortedRules = rules.sorted(by: { $0.priority < $1.priority })
        for (index, rule) in sortedRules.enumerated() {
            rule.priority = index
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        RuleListView()
    }
    .modelContainer(for: RoutingRule.self, inMemory: true)
}

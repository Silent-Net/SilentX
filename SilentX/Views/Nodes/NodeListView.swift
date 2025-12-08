//
//  NodeListView.swift
//  SilentX
//
//  List view displaying all proxy nodes with SwiftData @Query
//

import SwiftUI
import SwiftData

/// Main node list view
struct NodeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProxyNode.createdAt, order: .reverse) private var nodes: [ProxyNode]
    
    @State private var showAddSheet = false
    @State private var showDeleteAlert = false
    @State private var nodeToDelete: ProxyNode?
    @State private var selectedNode: ProxyNode?
    @State private var isTestingAll = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        Group {
            if nodes.isEmpty {
                emptyView
            } else {
                nodeList
            }
        }
        .navigationTitle("Proxy Nodes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    testAllNodes()
                } label: {
                    if isTestingAll {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Test All", systemImage: "speedometer")
                    }
                }
                .disabled(nodes.isEmpty || isTestingAll)
                
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Node", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddNodeSheet()
        }
        .sheet(item: $selectedNode) { node in
            EditNodeSheet(node: node)
        }
        .alert("Delete Node", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let node = nodeToDelete {
                    deleteNode(node)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(nodeToDelete?.name ?? "")\"?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Nodes", systemImage: "server.rack")
        } description: {
            Text("Add proxy nodes to your configuration.")
        } actions: {
            Button {
                showAddSheet = true
            } label: {
                Label("Add Node", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var nodeList: some View {
        List {
            ForEach(nodes) { node in
                NodeRowView(node: node)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNode = node
                    }
                    .contextMenu {
                        nodeContextMenu(for: node)
                    }
            }
            .onDelete(perform: deleteNodes)
            .onMove(perform: moveNodes)
        }
        .listStyle(.inset)
    }
    
    @ViewBuilder
    private func nodeContextMenu(for node: ProxyNode) -> some View {
        Button {
            selectedNode = node
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        
        Button {
            testNode(node)
        } label: {
            Label("Test Latency", systemImage: "speedometer")
        }
        
        Divider()
        
        Button {
            duplicateNode(node)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            nodeToDelete = node
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func deleteNodes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(nodes[index])
        }
        try? modelContext.save()
    }
    
    private func deleteNode(_ node: ProxyNode) {
        modelContext.delete(node)
        try? modelContext.save()
    }
    
    private func moveNodes(from source: IndexSet, to destination: Int) {
        // For now, just update order - actual ordering handled by sortOrder property
        try? modelContext.save()
    }
    
    private func duplicateNode(_ node: ProxyNode) {
        let duplicate = ProxyNode(
            name: "\(node.name) Copy",
            protocolType: node.protocolType,
            server: node.server,
            port: node.port
        )
        
        // Copy credentials
        duplicate.password = node.password
        duplicate.uuid = node.uuid
        duplicate.method = node.method
        duplicate.alterId = node.alterId
        duplicate.security = node.security
        duplicate.username = node.username
        duplicate.upMbps = node.upMbps
        duplicate.downMbps = node.downMbps
        duplicate.tls = node.tls
        duplicate.sni = node.sni
        duplicate.skipCertVerify = node.skipCertVerify
        
        modelContext.insert(duplicate)
        try? modelContext.save()
    }
    
    private func testNode(_ node: ProxyNode) {
        // Mock latency test - actual implementation will use the core
        Task { @MainActor in
            node.latency = Int.random(in: 50...500)
            node.lastLatencyTest = Date()
            try? modelContext.save()
        }
    }
    
    private func testAllNodes() {
        isTestingAll = true
        
        Task { @MainActor in
            for node in nodes {
                // Mock latency - actual implementation will test in parallel
                node.latency = Int.random(in: 50...500)
                node.lastLatencyTest = Date()
            }
            try? modelContext.save()
            isTestingAll = false
        }
    }
}

#Preview {
    NavigationStack {
        NodeListView()
    }
    .modelContainer(for: ProxyNode.self, inMemory: true)
}

//
//  GroupsViewModel.swift
//  SilentX
//
//  ViewModel for managing proxy groups state
//  Uses ConfigParser for structure (preserves config order)
//  Uses Clash API only for real-time status updates
//

import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
@Observable
final class GroupsViewModel {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.silentnet.silentx", category: "GroupsViewModel")
    private let clashAPI = ClashAPIClient.shared
    
    /// All proxy groups (ordered as in config file)
    var groups: [OutboundGroup] = []
    
    /// Currently selected group for detail view
    var selectedGroup: OutboundGroup?
    
    /// Loading state
    var isLoading = false
    
    /// Error message
    var errorMessage: String?
    
    /// Whether groups are available (proxy connected & API reachable)
    var isAvailable = false
    
    /// Testing state for batch latency test
    var isTesting = false
    
    /// Current active config path
    private var activeConfigPath: URL?
    
    // MARK: - Configuration
    
    /// Configure with active config path
    /// Note: ClashAPIClient is already configured with correct port by ConnectionService.connect()
    func configure(configPath: URL?) async {
        activeConfigPath = configPath
        isAvailable = await clashAPI.isAvailable()
        if isAvailable {
            await loadGroups()
        }
    }
    
    // MARK: - Data Loading
    
    /// Load all proxy groups
    /// 1. Parse config file to get structure and order
    /// 2. Use Clash API to get real-time status (current selection, delays)
    func loadGroups() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Try to parse groups from config file (preserves order)
            var parsedGroups: [OutboundGroup]?
            
            if let configPath = activeConfigPath {
                do {
                    let result = try ConfigParser.parseGroups(from: configPath)
                    parsedGroups = result.groups
                    logger.info("Parsed \(result.groups.count) groups from config file")
                } catch {
                    logger.warning("Failed to parse config file: \(error.localizedDescription)")
                }
            }
            
            // Step 2: Get real-time status from Clash API
            let response = try await clashAPI.getProxies()
            
            // Step 3: Merge - use config order but update with API status
            if let configGroups = parsedGroups {
                groups = mergeWithAPIStatus(configGroups: configGroups, apiProxies: response.proxies)
            } else {
                // Fallback: use Clash API order if config parsing failed
                groups = await clashAPI.parseGroups(from: response)
                logger.warning("Using Clash API order as fallback")
            }
            
            // Auto-select first group if none selected
            if selectedGroup == nil && !groups.isEmpty {
                selectedGroup = groups.first
            } else if let selected = selectedGroup {
                // Update selected group with new data
                selectedGroup = groups.first { $0.id == selected.id }
            }
            
            isAvailable = true
            logger.info("Loaded \(self.groups.count) groups")
            
        } catch let error as ClashAPIClient.ClashAPIError {
            errorMessage = error.localizedDescription
            isAvailable = false
            logger.error("Failed to load groups: \(error.localizedDescription)")
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            isAvailable = false
            logger.error("Failed to load groups: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Merge config groups with API real-time status
    private func mergeWithAPIStatus(
        configGroups: [OutboundGroup],
        apiProxies: [String: ClashProxyInfo]
    ) -> [OutboundGroup] {
        return configGroups.map { group in
            var updatedGroup = group
            
            // Update current selection from API
            if let apiInfo = apiProxies[group.tag] {
                if let now = apiInfo.now {
                    updatedGroup.selected = now
                }
            }
            
            // Update items with delay info and selection state
            updatedGroup.items = group.items.map { item in
                var updatedItem = item
                
                // Update delay from API
                if let proxyInfo = apiProxies[item.tag] {
                    updatedItem.delay = proxyInfo.latestDelay
                }
                
                // Update selection state
                updatedItem.isSelected = (item.tag == updatedGroup.selected)
                
                return updatedItem
            }
            
            return updatedGroup
        }
    }
    
    /// Refresh groups
    func refresh() async {
        await loadGroups()
    }
    
    // MARK: - Node Selection
    
    /// Select a node in a group
    func selectNode(in group: OutboundGroup, node: OutboundGroupItem) async {
        guard group.isSelectable else {
            logger.warning("Cannot select node in non-selector group: \(group.tag)")
            return
        }
        
        // Skip if already selected - avoid unnecessary API calls
        if node.isSelected || group.selected == node.tag {
            logger.debug("Node \(node.tag) is already selected, skipping")
            return
        }
        
        // Optimistic UI update
        let previousSelection = group.selected
        updateSelection(groupId: group.id, nodeTag: node.tag)
        
        do {
            try await clashAPI.selectProxy(group: group.tag, node: node.tag)
            logger.info("Selected \(node.tag) in \(group.tag)")
            
        } catch {
            // Revert on error
            updateSelection(groupId: group.id, nodeTag: previousSelection)
            errorMessage = "Failed to switch: \(error.localizedDescription)"
            logger.error("Failed to select node: \(error.localizedDescription)")
        }
    }
    
    /// Update selection state locally
    private func updateSelection(groupId: String, nodeTag: String) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].selected = nodeTag
            
            // Update isSelected for all items
            for itemIndex in groups[index].items.indices {
                groups[index].items[itemIndex].isSelected = (groups[index].items[itemIndex].tag == nodeTag)
            }
            
            // Update selected group reference
            if selectedGroup?.id == groupId {
                selectedGroup = groups[index]
            }
        }
    }
    
    // MARK: - Latency Testing
    
    /// Test latency for all nodes in a group
    func testLatency(for group: OutboundGroup) async {
        guard !isTesting else { return }
        
        isTesting = true
        
        // Mark all nodes as testing
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            for itemIndex in groups[index].items.indices {
                groups[index].items[itemIndex].isTesting = true
            }
            if selectedGroup?.id == group.id {
                selectedGroup = groups[index]
            }
        }
        
        // Get delays for all nodes
        let nodeTags = group.items.map { $0.tag }
        let delays = await clashAPI.getDelays(proxies: nodeTags)
        
        // Update delays
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            for itemIndex in groups[index].items.indices {
                let tag = groups[index].items[itemIndex].tag
                groups[index].items[itemIndex].delay = delays[tag]
                groups[index].items[itemIndex].isTesting = false
            }
            if selectedGroup?.id == group.id {
                selectedGroup = groups[index]
            }
        }
        
        isTesting = false
        logger.info("Tested latency for \(nodeTags.count) nodes in \(group.tag)")
    }
    
    /// Test latency for a single node
    func testLatency(for node: OutboundGroupItem, in group: OutboundGroup) async {
        // Mark node as testing
        updateNodeTesting(groupId: group.id, nodeTag: node.tag, isTesting: true)
        
        do {
            let delay = try await clashAPI.getDelay(proxy: node.tag)
            updateNodeDelay(groupId: group.id, nodeTag: node.tag, delay: delay)
            logger.debug("\(node.tag) delay: \(delay)ms")
        } catch {
            updateNodeDelay(groupId: group.id, nodeTag: node.tag, delay: -1)
            logger.warning("Failed to test \(node.tag): \(error.localizedDescription)")
        }
        
        updateNodeTesting(groupId: group.id, nodeTag: node.tag, isTesting: false)
    }
    
    private func updateNodeTesting(groupId: String, nodeTag: String, isTesting: Bool) {
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }),
           let itemIndex = groups[groupIndex].items.firstIndex(where: { $0.tag == nodeTag }) {
            groups[groupIndex].items[itemIndex].isTesting = isTesting
            if selectedGroup?.id == groupId {
                selectedGroup = groups[groupIndex]
            }
        }
    }
    
    private func updateNodeDelay(groupId: String, nodeTag: String, delay: Int) {
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }),
           let itemIndex = groups[groupIndex].items.firstIndex(where: { $0.tag == nodeTag }) {
            groups[groupIndex].items[itemIndex].delay = delay
            if selectedGroup?.id == groupId {
                selectedGroup = groups[groupIndex]
            }
        }
    }
    
    // MARK: - Expand/Collapse
    
    /// Toggle expand state for a group
    func toggleExpand(for group: OutboundGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isExpanded.toggle()
            if selectedGroup?.id == group.id {
                selectedGroup = groups[index]
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Clear all data (on disconnect)
    func clear() {
        groups = []
        selectedGroup = nil
        isAvailable = false
        errorMessage = nil
        activeConfigPath = nil
    }
}

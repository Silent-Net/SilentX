//
//  DashboardView.swift
//  SilentX
//
//  Main dashboard view showing connection status and controls
//

import SwiftUI
import SwiftData
import Combine

/// Main dashboard view with connection controls
struct DashboardView: View {
    @EnvironmentObject var connectionService: ConnectionService
    @Query private var allProfiles: [Profile]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    @AppStorage("proxyMode") private var savedProxyMode: String = "rule"
    
    // Dashboard appearance settings
    @AppStorage("dashboardStyle") private var dashboardStyle = DashboardStyle.compact
    @AppStorage("showSpeedGraph") private var showSpeedGraph = true
    
    var onNavigateToProfiles: (() -> Void)? = nil
    
    @State private var selectedProfile: Profile?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var proxyMode: ProxyMode = .rule
    
    private var activeProfile: Profile? {
        selectedProfile
    }
    
    private var isConnected: Bool {
        if case .connected = connectionService.status { return true }
        return false
    }
    
    private var dashboardSpacing: CGFloat {
        switch dashboardStyle {
        case .minimal: return 12
        case .compact: return 20
        case .detailed: return 24
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: dashboardSpacing) {
                // Connection status section
                ConnectionSection(
                    status: connectionService.status,
                    onConnect: handleConnect,
                    onDisconnect: handleDisconnect,
                    style: dashboardStyle
                )
                
                // Detailed mode: Extra connection info card
                if dashboardStyle == .detailed && isConnected {
                    DetailedConnectionInfoCard(connectionService: connectionService)
                        .padding(.horizontal)
                }
                
                // Speed Graph (only when connected and enabled)
                if isConnected && showSpeedGraph && dashboardStyle != .minimal {
                    SpeedGraphView()
                        .frame(maxWidth: dashboardStyle == .detailed ? 600 : 500, 
                               maxHeight: dashboardStyle == .detailed ? 180 : 120)
                        .padding(.horizontal)
                }
                
                // Mode Switcher (only visible when connected)
                if isConnected {
                    ModeSwitcherView(
                        selectedMode: $proxyMode,
                        isConnected: isConnected,
                        onModeChange: handleModeChange
                    )
                    .frame(maxWidth: dashboardStyle == .detailed ? 500 : 400)
                }
                
                // Profile selector (hide in minimal mode when connected)
                if dashboardStyle != .minimal || !isConnected {
                    ProfileSelectorView(
                        selectedProfile: $selectedProfile,
                        onManageProfiles: onNavigateToProfiles
                    )
                    .padding(.horizontal)
                }
                
                // System Proxy Controls (only visible when connected, hide in minimal)
                if isConnected && dashboardStyle != .minimal {
                    SystemProxyControlView()
                        .frame(maxWidth: dashboardStyle == .detailed ? 500 : 400)
                        .padding(.horizontal)
                }
                
                // Detailed mode: Quick stats at bottom
                if dashboardStyle == .detailed && isConnected {
                    QuickStatsView(connectionService: connectionService)
                        .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, dashboardStyle == .minimal ? 16 : (dashboardStyle == .detailed ? 28 : 24))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Dashboard")
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Load saved profile on launch (like SFM's SharedPreferences.selectedProfileID)
            loadSavedProfile()
        }
        .onChange(of: selectedProfile) { oldValue, newValue in
            // Save selected profile ID for next launch
            if let profile = newValue {
                selectedProfileID = profile.id.uuidString
                
                // Sync isSelected flag for Profiles page (bidirectional sync)
                for p in allProfiles {
                    p.isSelected = (p.id == profile.id)
                }
                try? modelContext.save()
                
                // Instant switch: if connected and profile changed, restart with new profile immediately
                if oldValue != nil && oldValue?.id != profile.id {
                    if case .connected = connectionService.status {
                        Task {
                            await handleProfileSwitch(to: profile)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedProfileID) { _, newID in
            // Sync when selectedProfileID is changed externally (e.g. from ProfileListView)
            guard !newID.isEmpty,
                  let uuid = UUID(uuidString: newID),
                  selectedProfile?.id != uuid else { return }
            
            if let profile = allProfiles.first(where: { $0.id == uuid }) {
                selectedProfile = profile
            }
        }
    }
    
    // MARK: - Profile Management
    
    /// Handle instant profile switch (disconnect + connect in one smooth operation)
    private func handleProfileSwitch(to profile: Profile) async {
        do {
            // Use restart for cleaner transition
            try await connectionService.disconnect()
            try await connectionService.connect(profile: profile)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func loadSavedProfile() {
        // Skip if profile is already loaded
        guard selectedProfile == nil else { return }
        
        // Restore last selected profile (mimics SFM's SharedPreferences.selectedProfileID.get())
        if !selectedProfileID.isEmpty, let uuid = UUID(uuidString: selectedProfileID) {
            // Find profile with saved ID
            if let savedProfile = allProfiles.first(where: { $0.id == uuid }) {
                selectedProfile = savedProfile
                return
            }
        }
        
        // Fallback: select first profile if saved ID not found
        if let firstProfile = allProfiles.first {
            selectedProfile = firstProfile
            selectedProfileID = firstProfile.id.uuidString
        }
    }
    
    // MARK: - Actions
    
    private func handleConnect() async {
        guard activeProfile != nil else {
            errorMessage = "Please select a profile first"
            showError = true
            return
        }
        
        do {
            if let profile = activeProfile {
                try await connectionService.connect(profile: profile)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleDisconnect() async {
        do {
            try await connectionService.disconnect()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleModeChange(_ mode: ProxyMode) async {
        do {
            try await connectionService.setProxyMode(mode.rawValue)
            savedProxyMode = mode.rawValue
        } catch {
            errorMessage = "Failed to change mode: \(error.localizedDescription)"
            showError = true
        }
    }
}

/// Connection status section with button - Apple Liquid Glass style
struct ConnectionSection: View {
    let status: ConnectionStatus
    let onConnect: () async -> Void
    let onDisconnect: () async -> Void
    var style: DashboardStyle = .compact
    
    private var verticalSpacing: CGFloat {
        switch style {
        case .minimal: return 12
        case .compact: return 24
        case .detailed: return 28
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .minimal: return 12
        case .compact: return 20
        case .detailed: return 28
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .minimal: return 16
        case .compact: return 24
        case .detailed: return 32
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .minimal: return 12
        case .compact: return 16
        case .detailed: return 20
        }
    }
    
    var body: some View {
        VStack(spacing: verticalSpacing) {
            // Large connect button - bigger in detailed mode
            ConnectButton(status: status, size: style == .detailed ? .large : .regular) {
                if status.isConnected {
                    await onDisconnect()
                } else {
                    await onConnect()
                }
            }
            
            // Status indicator (hide in minimal mode)
            if style != .minimal {
                ConnectionStatusView(status: status)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(color: .black.opacity(0.08), radius: style == .minimal ? 6 : 12, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Speed Graph View

/// Simple speed graph showing upload/download rates
struct SpeedGraphView: View {
    @EnvironmentObject var connectionService: ConnectionService
    @State private var uploadHistory: [Double] = Array(repeating: 0, count: 30)
    @State private var downloadHistory: [Double] = Array(repeating: 0, count: 30)
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 8) {
            // Speed labels
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("↑ \(formatSpeed(uploadHistory.last ?? 0))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                    Text("↓ \(formatSpeed(downloadHistory.last ?? 0))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            
            // Graph
            GeometryReader { geometry in
                ZStack {
                    // Download line (blue)
                    SpeedLine(values: downloadHistory, color: .blue, height: geometry.size.height)
                    
                    // Upload line (green)
                    SpeedLine(values: uploadHistory, color: .green, height: geometry.size.height)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .onAppear {
            startUpdating()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startUpdating() {
        // Update every second with simulated data (in real implementation, use actual traffic data)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Simulate speed data - in production, get from sing-box API
            let upload = Double.random(in: 0...1000000) // bytes/s
            let download = Double.random(in: 0...5000000) // bytes/s
            
            uploadHistory.append(upload)
            downloadHistory.append(download)
            
            if uploadHistory.count > 30 {
                uploadHistory.removeFirst()
            }
            if downloadHistory.count > 30 {
                downloadHistory.removeFirst()
            }
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f MB/s", bytesPerSecond / 1024 / 1024)
        }
    }
}

/// Line graph for speed visualization
struct SpeedLine: View {
    let values: [Double]
    let color: Color
    let height: CGFloat
    
    var body: some View {
        let maxValue = max(values.max() ?? 1, 1)
        
        GeometryReader { geometry in
            Path { path in
                guard values.count > 1 else { return }
                
                let width = geometry.size.width
                let stepX = width / Double(values.count - 1)
                
                path.move(to: CGPoint(
                    x: 0,
                    y: height * (1 - values[0] / maxValue)
                ))
                
                for (index, value) in values.enumerated() {
                    let x = Double(index) * stepX
                    let y = height * (1 - value / maxValue)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color.opacity(0.7), lineWidth: 1.5)
        }
    }
}

// MARK: - Detailed Mode Views

/// Extra connection info card for detailed mode
struct DetailedConnectionInfoCard: View {
    @ObservedObject var connectionService: ConnectionService
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        if case .connected(let info) = connectionService.status {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Label("Connection Details", systemImage: "info.circle")
                        .font(.headline)
                    Spacer()
                }
                
                // Info grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    InfoCell(
                        title: "Engine",
                        value: info.engineType.displayName,
                        icon: "gearshape.2"
                    )
                    
                    InfoCell(
                        title: "Duration",
                        value: info.formattedDuration(to: currentTime),
                        icon: "clock"
                    )
                    
                    InfoCell(
                        title: "Config",
                        value: info.configName.isEmpty ? "Unknown" : info.configName,
                        icon: "doc.text"
                    )
                    
                    InfoCell(
                        title: "Ports",
                        value: info.listenPorts.isEmpty ? "System" : info.listenPorts.map { String($0) }.joined(separator: ", "),
                        icon: "network"
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .onReceive(timer) { _ in
                currentTime = Date()
            }
        }
    }
}

/// Single info cell for detailed view
struct InfoCell: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

/// Quick stats bar for detailed mode
struct QuickStatsView: View {
    @ObservedObject var connectionService: ConnectionService
    @State private var activeConnections: Int = 0
    @State private var totalTraffic: (up: Int64, down: Int64) = (0, 0)
    
    var body: some View {
        HStack(spacing: 24) {
            StatItem(
                title: "Active",
                value: "\(activeConnections)",
                icon: "link",
                color: .blue
            )
            
            Divider()
                .frame(height: 30)
            
            StatItem(
                title: "Upload",
                value: formatBytes(totalTraffic.up),
                icon: "arrow.up",
                color: .green
            )
            
            Divider()
                .frame(height: 30)
            
            StatItem(
                title: "Download",
                value: formatBytes(totalTraffic.down),
                icon: "arrow.down",
                color: .orange
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .onAppear {
            fetchStats()
        }
        .task {
            // Periodically update stats
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                fetchStats()
            }
        }
    }
    
    private func fetchStats() {
        // Try to get stats from Clash API
        Task {
            if let port = connectionService.clashAPIPort {
                do {
                    // Fetch connections count
                    let connectionsURL = URL(string: "http://127.0.0.1:\(port)/connections")!
                    let (data, _) = try await URLSession.shared.data(from: connectionsURL)
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let connections = json["connections"] as? [[String: Any]] {
                        await MainActor.run {
                            activeConnections = connections.count
                        }
                    }
                    
                    // Get traffic stats
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let uploadTotal = json["uploadTotal"] as? Int64,
                       let downloadTotal = json["downloadTotal"] as? Int64 {
                        await MainActor.run {
                            totalTraffic = (uploadTotal, downloadTotal)
                        }
                    }
                } catch {
                    // Silently fail - stats are optional
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
        } else {
            return String(format: "%.2f GB", Double(bytes) / 1024 / 1024 / 1024)
        }
    }
}

/// Single stat item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(ConnectionService())
        .frame(width: 600, height: 500)
}

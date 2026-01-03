//
//  MenuBarView.swift
//  SilentX
//
//  Menu bar dropdown content for quick controls
//

import SwiftUI
import SwiftData

/// Menu bar dropdown view with quick connection controls
struct MenuBarView: View {
    @EnvironmentObject var connectionService: ConnectionService
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss  // To close menu bar popover
    @Query private var profiles: [Profile]
    @AppStorage("selectedProfileID") private var selectedProfileID: String = ""
    
    private var isConnected: Bool {
        if case .connected = connectionService.status { return true }
        return false
    }
    
    private var statusText: String {
        switch connectionService.status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
    
    private var selectedProfile: Profile? {
        profiles.first { $0.id.uuidString == selectedProfileID }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection
            
            Divider()
            
            // Profile selector
            profilesSection
            
            Divider()
            
            // Actions
            actionsSection
        }
        .frame(width: 240)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Circle()
                .fill(isConnected ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.headline)
            
            Spacer()
            
            // Apple-style Toggle switch
            Toggle("", isOn: Binding(
                get: { isConnected },
                set: { newValue in
                    Task {
                        if newValue {
                            if let profile = selectedProfile {
                                try? await connectionService.connect(profile: profile)
                            }
                        } else {
                            try? await connectionService.disconnect()
                        }
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Profiles Section
    
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Profiles")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            ForEach(profiles) { profile in
                ProfileRow(
                    profile: profile,
                    isSelected: profile.id.uuidString == selectedProfileID
                ) {
                    selectProfile(profile)
                }
            }
            
            if profiles.isEmpty {
                Text("No profiles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 2) {
            MenuRow(title: "Open SilentX", shortcut: "⌘O", action: openMainWindow)
            MenuRow(title: "Settings...", shortcut: "⌘,", action: openSettings)
            
            Divider()
            
            MenuRow(title: "Quit SilentX", shortcut: "⌘Q", action: quitApp)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func toggleConnection() {
        Task {
            if isConnected {
                try? await connectionService.disconnect()
            } else if let profile = selectedProfile {
                try? await connectionService.connect(profile: profile)
            }
        }
    }
    
    private func selectProfile(_ profile: Profile) {
        selectedProfileID = profile.id.uuidString
    }
    
    private func openMainWindow() {
        #if os(macOS)
        // Dismiss menu bar popover FIRST
        dismiss()
        
        // Switch to regular mode
        NSApp.setActivationPolicy(.regular)
        
        // Use async to let popover close first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            
            // Find existing main window (skip small popovers)
            let mainWindows = NSApp.windows.filter { window in
                window.canBecomeKey &&
                window.level == .normal &&
                window.frame.width >= 400 &&
                window.frame.height >= 300
            }
            
            if let existingWindow = mainWindows.first {
                // Close duplicates
                for window in mainWindows.dropFirst() {
                    window.close()
                }
                existingWindow.makeKeyAndOrderFront(nil)
                existingWindow.orderFrontRegardless()
            } else {
                self.openWindow(id: "main")
            }
        }
        #endif
    }
    
    private func openSettings() {
        #if os(macOS)
        // Dismiss menu bar popover FIRST
        dismiss()
        
        NSApp.setActivationPolicy(.regular)
        
        // Set pending navigation to Settings
        UserDefaults.standard.set("Settings", forKey: "pendingNavigation")
        
        // Use async to let popover close first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            
            // Find existing main window
            let mainWindows = NSApp.windows.filter { window in
                window.canBecomeKey &&
                window.level == .normal &&
                window.frame.width >= 400 &&
                window.frame.height >= 300
            }
            
            if let existingWindow = mainWindows.first {
                for window in mainWindows.dropFirst() {
                    window.close()
                }
                existingWindow.makeKeyAndOrderFront(nil)
                existingWindow.orderFrontRegardless()
            } else {
                self.openWindow(id: "main")
            }
        }
        #endif
    }
    
    private func quitApp() {
        #if os(macOS)
        NSApp.terminate(nil)
        #endif
    }

}

// MARK: - Profile Row

private struct ProfileRow: View {
    let profile: Profile
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                
                Text(profile.name)
                    .lineLimit(1)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.accentColor.opacity(0.15) : (isSelected ? Color.accentColor.opacity(0.1) : Color.clear))
        )
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Menu Row (with hover)

private struct MenuRow: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(ConnectionService())
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToSettings = Notification.Name("navigateToSettings")
}

//
//  GeneralSettingsView.swift
//  SilentX
//
//  General application settings
//

import SwiftUI
import ServiceManagement
#if os(macOS)
import AppKit
#endif

/// View for general application settings
struct GeneralSettingsView: View {
    // Auto-connect settings
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
    @AppStorage("autoReconnectOnDisconnect") private var autoReconnectOnDisconnect = true
    @AppStorage("reconnectDelay") private var reconnectDelay = 5.0
    
    // Update settings
    @AppStorage("autoCheckForUpdates") private var autoCheckForUpdates = true
    @AppStorage("autoDownloadUpdates") private var autoDownloadUpdates = false
    @AppStorage("includePrereleases") private var includePrereleases = false
    
    // Behavior settings
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("hideOnClose") private var hideOnClose = true
    @AppStorage("hideFromDock") private var hideFromDock = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    // Notification settings
    @AppStorage("notifyOnConnect") private var notifyOnConnect = true
    @AppStorage("notifyOnDisconnect") private var notifyOnDisconnect = true
    @AppStorage("notifyOnError") private var notifyOnError = true
    
    // Alert states
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    
    var body: some View {
        Form {
            // Connection Section
            Section {
                Toggle("Connect automatically on launch", isOn: $autoConnectOnLaunch)
                
                Toggle("Reconnect automatically on disconnect", isOn: $autoReconnectOnDisconnect)
                
                if autoReconnectOnDisconnect {
                    Picker("Reconnect delay", selection: $reconnectDelay) {
                        Text("Immediately").tag(0.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("30 seconds").tag(30.0)
                    }
                }
            } header: {
                Label("Connection", systemImage: "antenna.radiowaves.left.and.right")
            }
            
            // Updates Section
            Section {
                Toggle("Check for core updates automatically", isOn: $autoCheckForUpdates)
                
                Toggle("Download updates automatically", isOn: $autoDownloadUpdates)
                    .disabled(!autoCheckForUpdates)
                
                Toggle("Include pre-release versions", isOn: $includePrereleases)
                    .disabled(!autoCheckForUpdates)
            } header: {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
            } footer: {
                Text("SilentX will check for new Sing-Box core versions periodically.")
            }
            
            // Behavior Section
            Section {
                Toggle("Show in menu bar", isOn: $showInMenuBar)
                
                Toggle("Hide window on close (keep in menu bar)", isOn: $hideOnClose)
                    .disabled(!showInMenuBar)
                
                #if os(macOS)
                Toggle("Hide from Dock", isOn: Binding(
                    get: { hideFromDock },
                    set: { newValue in
                        hideFromDock = newValue
                        setDockVisibility(hidden: newValue)
                    }
                ))
                .disabled(!showInMenuBar)
                #endif
                
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
                ))
            } header: {
                Label("Behavior", systemImage: "rectangle.on.rectangle")
            } footer: {
                #if os(macOS)
                if hideFromDock {
                    Text("The app will only show in the menu bar. Use the menu bar icon to access SilentX.")
                        .foregroundStyle(.orange)
                }
                #endif
            }
            
            // Notifications Section
            Section {
                Toggle("Notify on connect", isOn: $notifyOnConnect)
                Toggle("Notify on disconnect", isOn: $notifyOnDisconnect)
                Toggle("Notify on errors", isOn: $notifyOnError)
            } header: {
                Label("Notifications", systemImage: "bell")
            } footer: {
                Text("Notifications require macOS notification permissions.")
            }
            
            // Data Management Section
            Section {
                Button {
                    openDataFolder()
                } label: {
                    Label("Open Data Folder in Finder", systemImage: "folder")
                }
                
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Label("Data Management", systemImage: "internaldrive")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Sync launch at login state with actual system state
            syncLaunchAtLoginState()
        }
        .alert("Reset All Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .alert("Settings Reset", isPresented: $showResetSuccess) {
            Button("OK") { }
        } message: {
            Text("All settings have been reset to their default values.")
        }
    }
    
    // MARK: - Private Methods
    
    /// Open the application data folder in Finder
    private func openDataFolder() {
        #if os(macOS)
        NSWorkspace.shared.open(FilePath.applicationSupport)
        #endif
    }
    
    /// Reset all @AppStorage settings to defaults
    private func resetAllSettings() {
        // List of all @AppStorage keys used in the app
        let keysToReset = [
            "autoConnectOnLaunch",
            "autoReconnectOnDisconnect",
            "reconnectDelay",
            "autoCheckForUpdates",
            "autoDownloadUpdates",
            "includePrereleases",
            "showInMenuBar",
            "hideOnClose",
            "launchAtLogin",
            "notifyOnConnect",
            "notifyOnDisconnect",
            "notifyOnError",
            "colorScheme",
            "accentColor",
            "sidebarIconsOnly",
            "showConnectionStats",
            "dashboardStyle",
            "showSpeedGraph",
            "logFontSize",
            "logColorCoding",
            "selectedProfileID",
            "hasCompletedOnboarding"
        ]
        
        for key in keysToReset {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Disable launch at login when resetting
        setLaunchAtLogin(enabled: false)
        
        showResetSuccess = true
    }
    
    /// Set or unset launch at login via SMAppService
    private func setLaunchAtLogin(enabled: Bool) {
        #if os(macOS)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            // Registration may fail in unsigned/development builds
            print("Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
            // Revert UI state
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        #endif
    }
    
    /// Sync the toggle state with the actual system state
    private func syncLaunchAtLoginState() {
        #if os(macOS)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        #endif
    }
    
    /// Set dock visibility using activation policy
    #if os(macOS)
    private func setDockVisibility(hidden: Bool) {
        if hidden {
            // Hide from Dock - show only in menu bar
            NSApp.setActivationPolicy(.accessory)
        } else {
            // Show in Dock normally
            NSApp.setActivationPolicy(.regular)
            // Bring window to front after showing in Dock
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    #endif
}

#Preview {
    GeneralSettingsView()
}

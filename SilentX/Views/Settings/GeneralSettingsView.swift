//
//  GeneralSettingsView.swift
//  SilentX
//
//  General application settings
//

import SwiftUI

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
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    // Notification settings
    @AppStorage("notifyOnConnect") private var notifyOnConnect = true
    @AppStorage("notifyOnDisconnect") private var notifyOnDisconnect = true
    @AppStorage("notifyOnError") private var notifyOnError = true
    
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
                
                Toggle("Launch at login", isOn: $launchAtLogin)
            } header: {
                Label("Behavior", systemImage: "rectangle.on.rectangle")
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
                    // Open data folder in Finder
                } label: {
                    Label("Open Data Folder in Finder", systemImage: "folder")
                }
                
                Button(role: .destructive) {
                    // Reset all settings
                } label: {
                    Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Label("Data Management", systemImage: "internaldrive")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
}

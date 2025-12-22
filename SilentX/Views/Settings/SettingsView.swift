//
//  SettingsView.swift
//  SilentX
//
//  Main settings view with tabs for different settings sections
//

import SwiftUI

/// Main settings view container with tabbed navigation
struct SettingsView: View {
    @State private var selectedTab = SettingsTab.proxyMode
    @State private var selectedProfile: Profile? = nil
    @EnvironmentObject private var connectionService: ConnectionService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProxyModeSettingsView(selectedProfile: $selectedProfile)
                .tabItem {
                    Label("Proxy Mode", systemImage: "network")
                }
                .tag(SettingsTab.proxyMode)
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(SettingsTab.appearance)
            
            CoreVersionListView()
                .tabItem {
                    Label("Core Versions", systemImage: "cpu")
                }
                .tag(SettingsTab.coreVersions)
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 600, minHeight: 450)
        .navigationTitle("Settings")
    }
}

/// Settings tab enumeration
enum SettingsTab: String, CaseIterable {
    case proxyMode
    case general
    case appearance
    case coreVersions
    case about
}

#Preview {
    SettingsView()
        .environmentObject(ConnectionService())
}

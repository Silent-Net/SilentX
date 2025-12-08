//
//  AppearanceSettingsView.swift
//  SilentX
//
//  Appearance and UI settings
//

import SwiftUI

/// View for appearance and UI customization settings
struct AppearanceSettingsView: View {
    // Theme settings
    @AppStorage("colorScheme") private var colorScheme = AppColorScheme.system
    @AppStorage("accentColor") private var accentColor = AppAccentColor.blue
    
    // Sidebar settings
    @AppStorage("sidebarIconsOnly") private var sidebarIconsOnly = false
    @AppStorage("showConnectionStats") private var showConnectionStats = true
    
    // Dashboard settings
    @AppStorage("dashboardStyle") private var dashboardStyle = DashboardStyle.compact
    @AppStorage("showSpeedGraph") private var showSpeedGraph = true
    
    // Log settings
    @AppStorage("logFontSize") private var logFontSize = 12.0
    @AppStorage("logColorCoding") private var logColorCoding = true
    
    var body: some View {
        Form {
            // Theme Section
            Section {
                Picker("Appearance", selection: $colorScheme) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Accent Color", selection: $accentColor) {
                    ForEach(AppAccentColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 12, height: 12)
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
            } header: {
                Label("Theme", systemImage: "paintbrush")
            }
            
            // Sidebar Section
            Section {
                Toggle("Show icons only in sidebar", isOn: $sidebarIconsOnly)
                Toggle("Show connection statistics in sidebar", isOn: $showConnectionStats)
            } header: {
                Label("Sidebar", systemImage: "sidebar.left")
            }
            
            // Dashboard Section
            Section {
                Picker("Dashboard Style", selection: $dashboardStyle) {
                    ForEach(DashboardStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                
                Toggle("Show speed graph", isOn: $showSpeedGraph)
            } header: {
                Label("Dashboard", systemImage: "gauge")
            }
            
            // Log Viewer Section
            Section {
                Slider(value: $logFontSize, in: 10...18, step: 1) {
                    Text("Font Size")
                } minimumValueLabel: {
                    Text("10")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("18")
                        .font(.caption)
                }
                
                Text("Sample log entry")
                    .font(.system(size: logFontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                
                Toggle("Color-code log levels", isOn: $logColorCoding)
            } header: {
                Label("Log Viewer", systemImage: "text.alignleft")
            }
            
            // Preview Section
            Section {
                previewCard
            } header: {
                Label("Preview", systemImage: "eye")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var previewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                
                Text("Connected")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Upload")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("1.2 MB/s")
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Download")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("5.6 MB/s")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Types

/// Application color scheme options
enum AppColorScheme: String, CaseIterable {
    case system
    case light
    case dark
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Application accent color options
enum AppAccentColor: String, CaseIterable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        }
    }
}

/// Dashboard display style options
enum DashboardStyle: String, CaseIterable {
    case compact
    case detailed
    case minimal
    
    var displayName: String {
        rawValue.capitalized
    }
}

#Preview {
    AppearanceSettingsView()
}

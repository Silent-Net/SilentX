//
//  ModeSwitcherView.swift
//  SilentX
//
//  Mode switcher for Rule/Global/Direct mode selection (like SFM)
//

import SwiftUI

/// Proxy mode matching Clash API modes
enum ProxyMode: String, CaseIterable {
    case rule = "rule"
    case global = "global"
    case direct = "direct"
    
    var displayName: String {
        switch self {
        case .rule: return "Rule"
        case .global: return "Global"
        case .direct: return "Direct"
        }
    }
    
    var icon: String {
        switch self {
        case .rule: return "arrow.triangle.branch"
        case .global: return "globe"
        case .direct: return "arrow.right"
        }
    }
    
    var description: String {
        switch self {
        case .rule: return "Traffic routed by rules"
        case .global: return "All traffic via proxy"
        case .direct: return "All traffic direct"
        }
    }
}

/// Mode switcher view with segmented control
struct ModeSwitcherView: View {
    @Binding var selectedMode: ProxyMode
    let isConnected: Bool
    let onModeChange: (ProxyMode) async -> Void
    
    @State private var isChanging = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Segmented picker
            Picker("Mode", selection: $selectedMode) {
                ForEach(ProxyMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!isConnected || isChanging)
            .onChange(of: selectedMode) { _, newMode in
                guard isConnected else { return }
                Task {
                    isChanging = true
                    await onModeChange(newMode)
                    isChanging = false
                }
            }
            
            // Mode description
            Text(selectedMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

/// Compact mode indicator for dashboard header
struct ModeIndicatorView: View {
    let mode: ProxyMode
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mode.icon)
                .font(.caption)
            Text(mode.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(modeColor.opacity(0.15))
        .foregroundStyle(modeColor)
        .cornerRadius(6)
    }
    
    private var modeColor: Color {
        switch mode {
        case .rule: return .blue
        case .global: return .orange
        case .direct: return .green
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ModeSwitcherView(
            selectedMode: .constant(.rule),
            isConnected: true,
            onModeChange: { _ in }
        )
        
        HStack(spacing: 12) {
            ModeIndicatorView(mode: .rule)
            ModeIndicatorView(mode: .global)
            ModeIndicatorView(mode: .direct)
        }
    }
    .padding()
}

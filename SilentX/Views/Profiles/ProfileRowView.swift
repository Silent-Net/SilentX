//
//  ProfileRowView.swift
//  SilentX
//
//  Row view for displaying a profile in the list
//

import SwiftUI

/// Row view for a single profile in the list
struct ProfileRowView: View {
    let profile: Profile
    
    var body: some View {
        HStack(spacing: 12) {
            profileContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ProfileRow")
    }
    
    @ViewBuilder
    private var profileContent: some View {
        HStack(spacing: 12) {
            // Profile type icon
            profileIcon
            
            // Profile info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    if profile.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 8) {
                    // Profile type badge
                    Text(profile.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(profile.type.color.opacity(0.2))
                        .clipShape(Capsule())
                    
                    // Last updated
                    Text(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Sync status for remote profiles
            if profile.type == .remote {
                syncStatus
            }
        }
        .padding(.vertical, 4)
    }
    
    private var profileIcon: some View {
        ZStack {
            Circle()
                .fill(profile.type.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: profile.type.iconName)
                .font(.system(size: 16))
                .foregroundStyle(profile.type.color)
        }
    }
    
    @ViewBuilder
    private var syncStatus: some View {
        if let lastSync = profile.lastSyncAt {
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastSync.formatted(.relative(presentation: .numeric)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Profile Type Extensions

extension ProfileType {
    var displayName: String {
        switch self {
        case .local: return "Local"
        case .remote: return "Remote"
        case .icloud: return "iCloud"
        }
    }
    
    var iconName: String {
        switch self {
        case .local: return "doc.fill"
        case .remote: return "cloud.fill"
        case .icloud: return "icloud.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .local: return .blue
        case .remote: return .orange
        case .icloud: return .cyan
        }
    }
}

#Preview {
    List {
        ProfileRowView(profile: Profile(
            name: "My Config",
            type: .local,
            configurationJSON: "{}"
        ))
        
        ProfileRowView(profile: {
            let p = Profile(
                name: "Work Profile",
                type: .remote,
                configurationJSON: "{}",
                remoteURL: "https://example.com/config.json"
            )
            p.isSelected = true
            p.lastSyncAt = Date().addingTimeInterval(-3600)
            return p
        }())
        
        ProfileRowView(profile: Profile(
            name: "iCloud Sync",
            type: .icloud,
            configurationJSON: "{}"
        ))
    }
}

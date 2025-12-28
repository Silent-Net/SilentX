//
//  ProfileSelectorView.swift
//  SilentX
//
//  Profile selector dropdown for dashboard
//

import SwiftUI
import SwiftData

/// Profile selector dropdown for choosing active profile
struct ProfileSelectorView: View {
    @Query(sort: \Profile.order) private var profiles: [Profile]
    @Binding var selectedProfile: Profile?
    var onManageProfiles: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Profile")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if profiles.isEmpty {
                EmptyProfileSelector()
            } else {
                Menu {
                    ForEach(profiles) { profile in
                        Button {
                            selectedProfile = profile
                        } label: {
                            HStack {
                                Label(profile.name, systemImage: profile.type.systemImage)
                                
                                if profile.id == selectedProfile?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        onManageProfiles?()
                    } label: {
                        Label("Manage Profiles...", systemImage: "gear")
                    }
                } label: {
                    ProfileSelectorLabel(profile: selectedProfile)
                }
                .menuStyle(.borderlessButton)
            }
        }
    }
}

/// Label for the profile selector menu
struct ProfileSelectorLabel: View {
    let profile: Profile?
    
    var body: some View {
        HStack {
            if let profile = profile {
                Image(systemName: profile.type.systemImage)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .fontWeight(.medium)
                    
                    Text("\(profile.enabledNodesCount) nodes • \(profile.enabledRulesCount) rules")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.secondary)
                
                Text("Select a Profile")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Empty state when no profiles exist
struct EmptyProfileSelector: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            
            Text("No profiles available. Import or create a profile to get started.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ProfileSelectorView(selectedProfile: .constant(nil))
        .padding()
        .frame(width: 300)
}

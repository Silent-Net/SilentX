//
//  CoreVersionRowView.swift
//  SilentX
//
//  Row view for a single core version
//

import SwiftUI

/// Row view displaying a single core version with status indicators
struct CoreVersionRowView: View {
    let version: CoreVersion
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Version icon with status
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "cpu")
                    .font(.title3)
                    .foregroundStyle(isActive ? .green : .secondary)
            }
            
            // Version info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("v\(version.version)")
                        .font(.headline)
                    
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    
                    if version.isPrerelease {
                        Text("PRE-RELEASE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    // Download date
                    if let downloadDate = version.downloadDate {
                        Label(downloadDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Status
                    Label(version.statusDisplay, systemImage: version.isDownloaded ? "checkmark.circle" : "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Checkmark for active version
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        CoreVersionRowView(
            version: {
                let v = CoreVersion(
                    version: "1.9.0",
                    downloadURL: "https://example.com/1.9.0.tar.gz"
                )
                v.downloadDate = Date()
                v.isActive = true
                v.localPath = "/path/to/sing-box"
                return v
            }(),
            isActive: true
        )
        
        CoreVersionRowView(
            version: {
                let v = CoreVersion(
                    version: "1.8.14",
                    downloadURL: "https://example.com/1.8.14.tar.gz"
                )
                v.downloadDate = Date().addingTimeInterval(-86400 * 30)
                v.localPath = "/path/to/sing-box"
                return v
            }(),
            isActive: false
        )
    }
    .padding()
}

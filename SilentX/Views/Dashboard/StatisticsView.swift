//
//  StatisticsView.swift
//  SilentX
//
//  Connection statistics display
//  TODO: Phase 6 - Re-implement statistics tracking
//

import SwiftUI

// TODO: Remove this placeholder when statistics tracking is re-implemented
struct ConnectionStatistics {
    let uploadBytes: Int64
    let downloadBytes: Int64
    let uploadSpeed: Int64
    let downloadSpeed: Int64
    let connectedDuration: TimeInterval?

    static let zero = ConnectionStatistics(
        uploadBytes: 0,
        downloadBytes: 0,
        uploadSpeed: 0,
        downloadSpeed: 0,
        connectedDuration: nil
    )

    var formattedUpload: String {
        ByteCountFormatter.string(fromByteCount: uploadBytes, countStyle: .binary)
    }

    var formattedDownload: String {
        ByteCountFormatter.string(fromByteCount: downloadBytes, countStyle: .binary)
    }

    var formattedUploadSpeed: String {
        "\(ByteCountFormatter.string(fromByteCount: uploadSpeed, countStyle: .binary))/s"
    }

    var formattedDownloadSpeed: String {
        "\(ByteCountFormatter.string(fromByteCount: downloadSpeed, countStyle: .binary))/s"
    }

    var formattedDuration: String {
        guard let duration = connectedDuration else { return "—" }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

/// View showing upload/download statistics
struct StatisticsView: View {
    let statistics: ConnectionStatistics
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 24) {
            // Upload stats
            StatBox(
                title: "Upload",
                value: statistics.formattedUpload,
                speed: isConnected ? statistics.formattedUploadSpeed : nil,
                systemImage: "arrow.up.circle.fill",
                color: .blue
            )

            // Download stats
            StatBox(
                title: "Download",
                value: statistics.formattedDownload,
                speed: isConnected ? statistics.formattedDownloadSpeed : nil,
                systemImage: "arrow.down.circle.fill",
                color: .green
            )

            // Duration
            StatBox(
                title: "Duration",
                value: statistics.formattedDuration,
                speed: nil,
                systemImage: "clock.fill",
                color: .orange
            )
        }
    }
}

/// Individual statistic box
struct StatBox: View {
    let title: String
    let value: String
    let speed: String?
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .fontDesign(.monospaced)

            if let speed = speed {
                Text(speed)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("With Data") {
    StatisticsView(
        statistics: ConnectionStatistics(
            uploadBytes: 1_234_567_890,
            downloadBytes: 9_876_543_210,
            uploadSpeed: 123_456,
            downloadSpeed: 987_654,
            connectedDuration: 3665
        ),
        isConnected: true
    )
    .padding()
}

#Preview("Disconnected") {
    StatisticsView(
        statistics: .zero,
        isConnected: false
    )
    .padding()
}

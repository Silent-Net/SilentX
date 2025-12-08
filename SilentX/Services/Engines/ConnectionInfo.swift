import Foundation

/// Details about an active connection
struct ConnectionInfo: Equatable {
    let engineType: EngineType
    let startTime: Date
    let configName: String
    let listenPorts: [Int]

    /// How long the connection has been active
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// Human-readable duration string
    var formattedDuration: String {
        let duration = self.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

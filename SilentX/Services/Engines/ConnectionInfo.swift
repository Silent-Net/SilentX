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
        formattedDuration(to: Date())
    }
    
    /// Human-readable duration string calculated to a specific time (T067)
    /// Used for live UI updates where currentTime is provided by a timer
    func formattedDuration(to currentTime: Date) -> String {
        let duration = currentTime.timeIntervalSince(startTime)
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

import Foundation

/// Configuration passed to proxy engine for startup
struct ProxyConfiguration {
    let profileId: UUID
    let configPath: URL
    let corePath: URL
    let logLevel: LogLevel

    enum LogLevel: String {
        case debug
        case info
        case warning
        case error
    }

    /// Validate that required files exist and are accessible
    func validate() throws {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw ProxyError.configNotFound
        }

        guard FileManager.default.isReadableFile(atPath: configPath.path) else {
            throw ProxyError.configInvalid("Configuration file is not readable")
        }

        guard FileManager.default.fileExists(atPath: corePath.path) else {
            throw ProxyError.coreNotFound
        }

        guard FileManager.default.isExecutableFile(atPath: corePath.path) else {
            throw ProxyError.coreStartFailed("Core file is not executable")
        }
    }
}

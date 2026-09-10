import Foundation

enum MuskometerNetworking {
    /// Ephemeral session — no disk/memory `URLCache` for Yahoo/SEC/GitHub payloads.
    /// Menu-bar apps stay resident; shared-session caching retained multi‑MB companyfacts.
    static let ephemeralSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()
}

/// US equity trading calendar timezone. Never fall back to device TZ — that
/// would corrupt day-scoped UserDefaults keys if the identifier ever failed.
enum EasternTimeZone {
    static let americaNewYork: TimeZone = {
        guard let timeZone = TimeZone(identifier: "America/New_York") else {
            preconditionFailure("America/New_York timezone is required")
        }
        return timeZone
    }()
}

import Foundation

enum AppURLs {
    static let website = URL(string: "https://muskometer.org")!
    /// Full disclaimer on GitHub (also linked from muskometer.org / GitHub Pages).
    static let disclaimer = URL(string: "https://github.com/jlgolson/muskometer/blob/main/docs/DISCLAIMER.md")!
    static let github = URL(string: "https://github.com/jlgolson/muskometer")!
    static let author = URL(string: "https://jordangolson.com")!
    static let contact = URL(string: "mailto:info@muskometer.org")!
    static let releasesLatest = URL(string: "https://github.com/jlgolson/muskometer/releases/latest")!

    /// Only open release links that point at this repo's GitHub release pages.
    static func isTrustedReleasePageURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else { return false }
        guard let host = url.host?.lowercased(), host == "github.com" else { return false }
        let path = url.path.lowercased()
        return path.hasPrefix("/jlgolson/muskometer/")
    }
}
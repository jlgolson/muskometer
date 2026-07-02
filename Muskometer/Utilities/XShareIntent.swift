import AppKit
import Foundation

enum XShareIntent {
    private static let baseURL = URL(string: "https://x.com/intent/tweet")!

    static func tweetURL(for snapshot: GainsSnapshot) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "text", value: GainSummaryFormatter.format(snapshot))
        ]
        return components?.url
    }

    @discardableResult
    static func openTweetComposer(for snapshot: GainsSnapshot) -> Bool {
        guard let url = tweetURL(for: snapshot) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
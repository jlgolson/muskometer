import Foundation

final class GitHubReleaseUpdateChecker: UpdateChecking, @unchecked Sendable {
    static let apiURL = URL(string: "https://api.github.com/repos/jlgolson/muskometer/releases/latest")!

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL
        let publishedAt: Date?
        let prerelease: Bool

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case publishedAt = "published_at"
            case prerelease
        }
    }

    private let session: URLSession
    private let apiURL: URL
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        apiURL: URL = GitHubReleaseUpdateChecker.apiURL
    ) {
        self.session = session
        self.apiURL = apiURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func checkForUpdate(currentVersion: String) async throws -> UpdateCheckResult? {
        var request = URLRequest(url: apiURL)
        request.setValue("Muskometer/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse(statusCode: -1)
        }
        guard httpResponse.statusCode == 200 else {
            throw UpdateCheckError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        let release = try decoder.decode(GitHubRelease.self, from: data)
        guard !release.prerelease else { return nil }

        let availableVersion = Self.normalizedVersion(from: release.tagName)
        guard SemanticVersion.isNewer(availableVersion, than: currentVersion) else {
            return nil
        }

        return UpdateCheckResult(
            availableVersion: availableVersion,
            releasePageURL: release.htmlURL,
            publishedAt: release.publishedAt
        )
    }

    private static func normalizedVersion(from tagName: String) -> String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}
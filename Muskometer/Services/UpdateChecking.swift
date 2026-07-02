import Foundation

protocol UpdateChecking: Sendable {
    func checkForUpdate(currentVersion: String) async throws -> UpdateCheckResult?
}

struct UpdateCheckResult: Equatable, Sendable {
    let availableVersion: String
    let releasePageURL: URL
    let publishedAt: Date?
}

enum UpdateCheckError: LocalizedError, Equatable {
    case invalidResponse(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            return "Could not check for updates (HTTP \(statusCode))."
        }
    }
}
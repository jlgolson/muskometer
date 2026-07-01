import Foundation

struct HoldingsSyncResult: Sendable {
    let tslaShares: Int64?
    let spcxShares: Int64?
    let syncedAt: Date
    let sourceDescription: String
}

enum HoldingsSyncError: LocalizedError {
    case invalidResponse
    case noFilingsFound
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Could not parse SEC EDGAR response."
        case .noFilingsFound:
            return "No recent Form 4 filings found for Elon Musk."
        case .networkError(let underlying):
            return underlying.localizedDescription
        }
    }
}

protocol HoldingsSyncServiceProtocol: Sendable {
    func syncHoldings() async throws -> HoldingsSyncResult
}
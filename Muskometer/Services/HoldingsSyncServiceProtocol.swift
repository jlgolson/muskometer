import Foundation

struct HoldingsSyncResult: Sendable {
    let sharesBySymbol: [String: Int64]
    let syncedAt: Date
    let sourceDescription: String
}

enum HoldingsSyncError: LocalizedError {
    case invalidResponse
    case noFilingsFound(personName: String)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Could not parse SEC EDGAR response."
        case .noFilingsFound(let personName):
            return "No recent Form 4 filings found for \(personName)."
        case .networkError(let underlying):
            return underlying.localizedDescription
        }
    }
}

protocol HoldingsSyncServiceProtocol: Sendable {
    func syncHoldings() async throws -> HoldingsSyncResult
}
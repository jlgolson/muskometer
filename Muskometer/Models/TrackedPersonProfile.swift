import Foundation

enum HoldingParseStrategy: String, Sendable, Codable {
    case directBeneficial
    case spcxAggregate
}

struct TrackedHoldingSpec: Identifiable, Sendable, Equatable {
    let id: String
    let symbol: String
    let displayName: String
    let defaultShareCount: Int64
    let parseStrategy: HoldingParseStrategy
}

struct TrackedPersonProfile: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let possessiveName: String
    let tagline: String
    let secCIKPadded: String
    let secCIKNumeric: String
    let holdingSpecs: [TrackedHoldingSpec]

    var expectedSymbols: Set<String> {
        Set(holdingSpecs.map(\.symbol))
    }

    static let registry: [TrackedPersonProfile] = [.musk]

    static let musk = TrackedPersonProfile(
        id: "musk",
        displayName: "Elon Musk",
        possessiveName: "Elon's",
        tagline: "What's Elon up to today?",
        secCIKPadded: "0001494730",
        secCIKNumeric: "1494730",
        holdingSpecs: [
            TrackedHoldingSpec(
                id: "tsla",
                symbol: "TSLA",
                displayName: "Tesla",
                defaultShareCount: 699_580_882,
                parseStrategy: .directBeneficial
            ),
            TrackedHoldingSpec(
                id: "spcx",
                symbol: "SPCX",
                displayName: "SpaceX",
                defaultShareCount: 6_068_734_060,
                parseStrategy: .spcxAggregate
            )
        ]
    )

    static func profile(for id: String) -> TrackedPersonProfile {
        registry.first { $0.id == id } ?? .musk
    }
}
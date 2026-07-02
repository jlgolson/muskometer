import Foundation

protocol ComparisonRandomizing {
    mutating func nextIndex(upperBound: Int) -> Int
}

struct SystemComparisonRandomizer: ComparisonRandomizing {
    private var generator = SystemRandomNumberGenerator()

    mutating func nextIndex(upperBound: Int) -> Int {
        Int.random(in: 0..<upperBound, using: &generator)
    }
}

/// Deterministic selector for unit tests.
struct SeededComparisonRandomizer: ComparisonRandomizing {
    private var seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    mutating func nextIndex(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        seed = seed &* 6_963_169_690_773_745 &+ 1_039_522_247
        return Int(seed % UInt64(upperBound))
    }
}

/// Picks a contextual comparison caption for the current paper gain.
@MainActor
final class ComparisonLineSelector {
    private var historyStore: ComparisonHistoryStore
    private var randomizer: any ComparisonRandomizing

    init(
        historyStore: ComparisonHistoryStore = ComparisonHistoryStore(),
        randomizer: any ComparisonRandomizing = SystemComparisonRandomizer()
    ) {
        self.historyStore = historyStore
        self.randomizer = randomizer
    }

    func selectLine(for paperGain: Double, on date: Date = .now) -> ComparisonLine? {
        let magnitude = abs(paperGain)
        guard magnitude > 0 else { return nil }

        let recentlyUsed = historyStore.recentlyUsedEntryIDs(on: date)
        var candidates = ComparisonLibrary.candidates(forMagnitude: magnitude)
            .filter { !recentlyUsed.contains($0.id) }

        if candidates.isEmpty {
            candidates = ComparisonLibrary.candidates(forMagnitude: magnitude)
        }

        guard !candidates.isEmpty else { return nil }

        var randomizer = randomizer
        let index = randomizer.nextIndex(upperBound: candidates.count)
        self.randomizer = randomizer

        let chosen = candidates[index]
        historyStore.recordUse(entryID: chosen.id, on: date)
        return chosen.line(forGain: paperGain)
    }
}
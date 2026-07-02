import Foundation

/// A single intraday combined paper-gain observation used for the popover sparkline.
struct GainSample: Codable, Equatable, Sendable, Identifiable {
    let timestamp: Date
    let combinedPaperGain: Double

    var id: Date { timestamp }

    init(timestamp: Date, combinedPaperGain: Double) {
        self.timestamp = timestamp
        self.combinedPaperGain = combinedPaperGain
    }
}
import Foundation

/// A single intraday or end-of-day gain/loss extreme tracked by `DailyRecordTracker`.
struct DailyGainRecord: Equatable, Sendable, Identifiable {
    let id: String
    let amount: Double
    let date: Date

    init(id: String = UUID().uuidString, amount: Double, date: Date) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}
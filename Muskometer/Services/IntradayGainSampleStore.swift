import Foundation

/// Persists intraday combined paper-gain samples for the current US/Eastern trading day.
final class IntradayGainSampleStore {
    static let maxSampleCount = 400
    private static let storageKey = "intradayGainSampleStore"

    private struct StoredState: Codable, Equatable {
        var dayKey: String
        var samples: [GainSample]
    }

    private(set) var samples: [GainSample] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let marketHours: any MarketHoursServiceProtocol
    private var currentDayKey: String

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = easternTradingCalendar(),
        marketHours: any MarketHoursServiceProtocol = MarketHoursService(
            calendar: easternTradingCalendar(),
            timeZone: TimeZone(identifier: "America/New_York") ?? .current
        )
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.marketHours = marketHours

        if let stored = Self.loadState(from: defaults) {
            samples = stored.samples
            currentDayKey = stored.dayKey
        } else {
            currentDayKey = Self.dayKey(for: .now, calendar: calendar)
        }
    }

    /// Records a sample when the US market is open. Clears prior samples on ET day rollover.
    func append(combinedPaperGain: Double, at date: Date = .now) {
        guard marketHours.isMarketOpen(at: date) else { return }

        let dayKey = Self.dayKey(for: date, calendar: calendar)
        if dayKey != currentDayKey {
            samples = []
            currentDayKey = dayKey
        }

        samples.append(GainSample(timestamp: date, combinedPaperGain: combinedPaperGain))

        if samples.count > Self.maxSampleCount {
            samples.removeFirst(samples.count - Self.maxSampleCount)
        }

        persist()
    }

    private func persist() {
        let state = StoredState(dayKey: currentDayKey, samples: samples)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func loadState(from defaults: UserDefaults) -> StoredState? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(StoredState.self, from: data)
    }

    static func easternCalendar() -> Calendar {
        easternTradingCalendar()
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private func easternTradingCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    return calendar
}
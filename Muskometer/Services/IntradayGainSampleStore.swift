import Foundation

/// Persists intraday combined paper-gain samples for the current US/Eastern trading day.
@MainActor
final class IntradayGainSampleStore {
    static let maxSampleCount = 400
    private static let legacyStorageKey = "intradayGainSampleStore"

    private struct StoredState: Codable, Equatable {
        var dayKey: String
        var samples: [GainSample]
    }

    private(set) var samples: [GainSample] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let marketHours: any MarketHoursServiceProtocol
    private let now: () -> Date
    private var activePersonID: String?
    private var currentDayKey: String

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = easternTradingCalendar(),
        marketHours: any MarketHoursServiceProtocol = MarketHoursService(
            calendar: easternTradingCalendar(),
            timeZone: TimeZone(identifier: "America/New_York") ?? .current
        ),
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.marketHours = marketHours
        self.now = now
        self.currentDayKey = Self.dayKey(for: now(), calendar: calendar)
    }

    /// Records a sample during quotable US equity hours. Clears prior samples on ET day rollover.
    func append(personID: String, combinedPaperGain: Double, at date: Date = .now) {
        loadStateIfNeeded(for: personID, referenceDate: date)

        // Day rollover (and persistence of empty state) runs even when closed so sparklines
        // do not keep yesterday's samples overnight / across non-quotable refreshes.
        guard marketHours.isQuotable(at: date) else { return }

        samples.append(GainSample(timestamp: date, combinedPaperGain: combinedPaperGain))

        if samples.count > Self.maxSampleCount {
            samples.removeFirst(samples.count - Self.maxSampleCount)
        }

        persist(for: personID)
    }

    func loadSamples(for personID: String) -> [GainSample] {
        loadStateIfNeeded(for: personID, referenceDate: now())
        return samples
    }

    /// Clears the in-memory person cache and reloads samples from `UserDefaults`.
    func reloadFromDefaults(for personID: String) {
        activePersonID = nil
        loadStateIfNeeded(for: personID, referenceDate: now())
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "intradayGainSampleStore_\(personID)")
        if personID == TrackedPersonProfile.musk.id {
            defaults.removeObject(forKey: "intradayGainSampleStore")
        }
    }

    private func loadStateIfNeeded(for personID: String, referenceDate: Date) {
        if activePersonID != personID {
            Self.migrateLegacyIfNeeded(defaults: defaults, personID: personID)

            if let stored = Self.loadState(from: defaults, personID: personID) {
                samples = stored.samples
                currentDayKey = stored.dayKey
            } else {
                samples = []
                currentDayKey = Self.dayKey(for: referenceDate, calendar: calendar)
            }

            activePersonID = personID
        }

        ensureCurrentDayState(at: referenceDate, personID: personID)
    }

    /// Drops samples when `referenceDate` is a different ET calendar day than `currentDayKey`.
    private func ensureCurrentDayState(at referenceDate: Date, personID: String) {
        let dayKey = Self.dayKey(for: referenceDate, calendar: calendar)
        guard dayKey != currentDayKey else { return }

        samples = []
        currentDayKey = dayKey
        persist(for: personID)
    }

    private func persist(for personID: String) {
        let state = StoredState(dayKey: currentDayKey, samples: samples)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey(personID: personID))
    }

    private static func storageKey(personID: String) -> String {
        "intradayGainSampleStore_\(personID)"
    }

    private static func loadState(from defaults: UserDefaults, personID: String) -> StoredState? {
        guard let data = defaults.data(forKey: storageKey(personID: personID)) else { return nil }
        return try? JSONDecoder().decode(StoredState.self, from: data)
    }

    private static func migrateLegacyIfNeeded(defaults: UserDefaults, personID: String) {
        guard personID == TrackedPersonProfile.musk.id else { return }
        let key = storageKey(personID: personID)
        guard defaults.data(forKey: key) == nil,
              let legacyData = defaults.data(forKey: legacyStorageKey) else {
            return
        }
        defaults.set(legacyData, forKey: key)
        defaults.removeObject(forKey: legacyStorageKey)
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
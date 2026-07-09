import Foundation

/// Persists intraday combined paper-gain samples for the most recent US/Eastern RTH session.
///
/// Samples are recorded only while the market is quotable (regular session). After the session
/// ends — including overnight past ET midnight — the last completed session's samples remain
/// available for display/share until the next RTH day appends its first sample.
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
    /// ET calendar day key of the RTH session that produced `samples`.
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

    /// Records a sample during quotable US equity hours.
    ///
    /// On the first sample of a new RTH trading day (ET day key), clears prior-session samples
    /// and starts a fresh series. Non-quotable times never append and never wipe stored samples.
    func append(personID: String, combinedPaperGain: Double, at date: Date = .now) {
        loadStateIfNeeded(for: personID)

        guard marketHours.isQuotable(at: date) else { return }

        let sampleDayKey = Self.dayKey(for: date, calendar: calendar)
        if sampleDayKey != currentDayKey {
            samples = []
            currentDayKey = sampleDayKey
        }

        samples.append(GainSample(timestamp: date, combinedPaperGain: combinedPaperGain))

        if samples.count > Self.maxSampleCount {
            samples.removeFirst(samples.count - Self.maxSampleCount)
        }

        persist(for: personID)
    }

    /// Returns stored samples for display, including the last completed RTH session overnight.
    ///
    /// Does **not** clear samples when the ET calendar day advances while the market is closed.
    func loadSamples(for personID: String) -> [GainSample] {
        loadStateIfNeeded(for: personID)
        return samples
    }

    /// Clears the in-memory person cache and reloads samples from `UserDefaults`.
    func reloadFromDefaults(for personID: String) {
        activePersonID = nil
        loadStateIfNeeded(for: personID)
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "intradayGainSampleStore_\(personID)")
        if personID == TrackedPersonProfile.musk.id {
            defaults.removeObject(forKey: "intradayGainSampleStore")
        }
    }

    private func loadStateIfNeeded(for personID: String) {
        guard activePersonID != personID else { return }

        Self.migrateLegacyIfNeeded(defaults: defaults, personID: personID)

        if let stored = Self.loadState(from: defaults, personID: personID) {
            samples = stored.samples
            currentDayKey = stored.dayKey
        } else {
            samples = []
            currentDayKey = Self.dayKey(for: now(), calendar: calendar)
        }

        activePersonID = personID
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

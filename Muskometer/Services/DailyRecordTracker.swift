import Foundation

/// Tracks best and worst daily paper gains since install, keyed by `personID`.
@MainActor
final class DailyRecordTracker {
    struct Snapshot: Equatable, Sendable {
        let bestRecord: DailyGainRecord?
        let worstRecord: DailyGainRecord?
        let hasCompletedFirstTradingDay: Bool
    }

    private struct PersistedRecord: Codable, Equatable {
        let amount: Double
        let date: Date
    }

    private struct DayExtremes: Equatable {
        var peak: Double
        var trough: Double
        var lastSampleDate: Date
        var hadOpenMarketSample: Bool
    }

    private let defaults: UserDefaults
    private let calendar: TradingDayCalendar
    private let marketHours: any MarketHoursServiceProtocol

    private var dayExtremesByPerson: [String: DayExtremes] = [:]
    private var currentDayKeyByPerson: [String: String] = [:]
    private var completedDayKeysByPerson: [String: Set<String>] = [:]
    private var openMarketSampleDayKeysByPerson: [String: Set<String>] = [:]

    init(
        defaults: UserDefaults = .standard,
        calendar: TradingDayCalendar = TradingDayCalendar(),
        marketHours: any MarketHoursServiceProtocol = MarketHoursService()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.marketHours = marketHours
    }

    func resetRuntimeState(for personID: String) {
        dayExtremesByPerson.removeValue(forKey: personID)
        currentDayKeyByPerson.removeValue(forKey: personID)
        completedDayKeysByPerson.removeValue(forKey: personID)
        openMarketSampleDayKeysByPerson.removeValue(forKey: personID)
    }

    func snapshot(for personID: String) -> Snapshot {
        let hasCompleted = defaults.bool(forKey: Self.firstDayCompleteKey(personID))
        guard hasCompleted else {
            return Snapshot(bestRecord: nil, worstRecord: nil, hasCompletedFirstTradingDay: false)
        }

        return Snapshot(
            bestRecord: loadRecord(forKey: Self.bestKey(personID)),
            worstRecord: loadRecord(forKey: Self.worstKey(personID)),
            hasCompletedFirstTradingDay: true
        )
    }

    @discardableResult
    func update(
        personID: String,
        paperGain: Double,
        at date: Date = .now,
        marketIsOpen: Bool
    ) -> Snapshot {
        let dayKey = calendar.dayKey(for: date)

        if defaults.string(forKey: Self.installDayKey(personID)) == nil {
            defaults.set(dayKey, forKey: Self.installDayKey(personID))
        }

        rolloverDayIfNeeded(personID: personID, to: dayKey, at: date)

        if marketIsOpen {
            var sampledDays = openMarketSampleDayKeysByPerson[personID] ?? []
            sampledDays.insert(dayKey)
            openMarketSampleDayKeysByPerson[personID] = sampledDays
        }

        var extremes = dayExtremesByPerson[personID] ?? DayExtremes(
            peak: paperGain,
            trough: paperGain,
            lastSampleDate: date,
            hadOpenMarketSample: marketIsOpen
        )
        extremes.peak = max(extremes.peak, paperGain)
        extremes.trough = min(extremes.trough, paperGain)
        extremes.lastSampleDate = date
        if marketIsOpen {
            extremes.hadOpenMarketSample = true
        }
        dayExtremesByPerson[personID] = extremes
        currentDayKeyByPerson[personID] = dayKey

        if extremes.hadOpenMarketSample,
           calendar.hasTradingDayCompleted(dayKey: dayKey, at: date, marketHours: marketHours) {
            finalizeTradingDay(personID: personID, dayKey: dayKey, extremes: extremes)
            markFirstTradingDayCompleteIfNeeded(personID: personID, completedDayKey: dayKey, at: date)
        }

        return snapshot(for: personID)
    }

    private func rolloverDayIfNeeded(personID: String, to newDayKey: String, at date: Date) {
        guard let previousDayKey = currentDayKeyByPerson[personID], previousDayKey != newDayKey else {
            return
        }

        if let extremes = dayExtremesByPerson[personID] {
            finalizeTradingDay(personID: personID, dayKey: previousDayKey, extremes: extremes)
            markFirstTradingDayCompleteIfNeeded(personID: personID, completedDayKey: previousDayKey, at: date)
        }

        dayExtremesByPerson[personID] = nil
    }

    private func finalizeTradingDay(personID: String, dayKey: String, extremes: DayExtremes) {
        guard extremes.hadOpenMarketSample else { return }

        var completed = completedDayKeysByPerson[personID] ?? []
        guard !completed.contains(dayKey) else { return }
        completed.insert(dayKey)
        completedDayKeysByPerson[personID] = completed

        updateBestIfNeeded(personID: personID, amount: extremes.peak, date: extremes.lastSampleDate)
        updateWorstIfNeeded(personID: personID, amount: extremes.trough, date: extremes.lastSampleDate)
    }

    private func markFirstTradingDayCompleteIfNeeded(personID: String, completedDayKey: String, at date: Date) {
        guard !defaults.bool(forKey: Self.firstDayCompleteKey(personID)) else { return }
        guard calendar.hasTradingDayCompleted(dayKey: completedDayKey, at: date, marketHours: marketHours) else {
            return
        }
        guard openMarketSampleDayKeysByPerson[personID]?.contains(completedDayKey) == true else {
            return
        }
        defaults.set(true, forKey: Self.firstDayCompleteKey(personID))
    }

    private func updateBestIfNeeded(personID: String, amount: Double, date: Date) {
        let key = Self.bestKey(personID)
        if let existing = loadRecord(forKey: key), amount <= existing.amount {
            return
        }
        storeRecord(PersistedRecord(amount: amount, date: date), forKey: key)
    }

    private func updateWorstIfNeeded(personID: String, amount: Double, date: Date) {
        let key = Self.worstKey(personID)
        if let existing = loadRecord(forKey: key), amount >= existing.amount {
            return
        }
        storeRecord(PersistedRecord(amount: amount, date: date), forKey: key)
    }

    private func loadRecord(forKey key: String) -> DailyGainRecord? {
        guard let data = defaults.data(forKey: key),
              let persisted = try? JSONDecoder().decode(PersistedRecord.self, from: data) else {
            return nil
        }
        return DailyGainRecord(amount: persisted.amount, date: persisted.date)
    }

    private func storeRecord(_ record: PersistedRecord, forKey key: String) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    private static func bestKey(_ personID: String) -> String {
        "dailyRecordBest_\(personID)"
    }

    private static func worstKey(_ personID: String) -> String {
        "dailyRecordWorst_\(personID)"
    }

    private static func installDayKey(_ personID: String) -> String {
        "dailyRecordInstallDay_\(personID)"
    }

    private static func firstDayCompleteKey(_ personID: String) -> String {
        "dailyRecordFirstDayComplete_\(personID)"
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "dailyRecordBest_\(personID)")
        defaults.removeObject(forKey: "dailyRecordWorst_\(personID)")
        defaults.removeObject(forKey: "dailyRecordInstallDay_\(personID)")
        defaults.removeObject(forKey: "dailyRecordFirstDayComplete_\(personID)")
    }
}
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

    /// In-progress peak/trough for the current ET trading day (memory + UserDefaults).
    private struct DayExtremes: Equatable, Codable {
        var peak: Double
        var trough: Double
        var lastSampleDate: Date
        var dayKey: String
        var hadQuotableSample: Bool
    }

    private let defaults: UserDefaults
    private let calendar: TradingDayCalendar
    private let marketHours: any MarketHoursServiceProtocol

    private var dayExtremesByPerson: [String: DayExtremes] = [:]
    private var currentDayKeyByPerson: [String: String] = [:]
    private var completedDayKeysByPerson: [String: Set<String>] = [:]
    private var quotableSampleDayKeysByPerson: [String: Set<String>] = [:]
    /// Persons whose unfinished extremes have been loaded from UserDefaults this runtime session.
    private var loadedUnfinishedPersonIDs: Set<String> = []

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
        quotableSampleDayKeysByPerson.removeValue(forKey: personID)
        loadedUnfinishedPersonIDs.remove(personID)
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
        isQuotable: Bool
    ) -> Snapshot {
        loadUnfinishedDayExtremesIfNeeded(for: personID)

        let dayKey = calendar.dayKey(for: date)

        if defaults.string(forKey: Self.installDayKey(personID)) == nil {
            defaults.set(dayKey, forKey: Self.installDayKey(personID))
        }

        rolloverDayIfNeeded(personID: personID, to: dayKey, at: date)

        // Always track the ET day key so overnight/closed refreshes can roll over and
        // finalize prior days without inventing peak/trough from non-quotable gains.
        currentDayKeyByPerson[personID] = dayKey

        if isQuotable {
            var sampledDays = quotableSampleDayKeysByPerson[personID] ?? []
            sampledDays.insert(dayKey)
            quotableSampleDayKeysByPerson[personID] = sampledDays

            var extremes = dayExtremesByPerson[personID] ?? DayExtremes(
                peak: paperGain,
                trough: paperGain,
                lastSampleDate: date,
                dayKey: dayKey,
                hadQuotableSample: true
            )
            // If memory still holds a different day's extremes (should be rare after rollover), reseat.
            if extremes.dayKey != dayKey {
                extremes = DayExtremes(
                    peak: paperGain,
                    trough: paperGain,
                    lastSampleDate: date,
                    dayKey: dayKey,
                    hadQuotableSample: true
                )
            } else {
                extremes.peak = max(extremes.peak, paperGain)
                extremes.trough = min(extremes.trough, paperGain)
                extremes.lastSampleDate = date
                extremes.hadQuotableSample = true
            }
            dayExtremesByPerson[personID] = extremes
            persistUnfinishedDayExtremes(extremes, for: personID)
        }

        if let extremes = dayExtremesByPerson[personID],
           extremes.hadQuotableSample,
           calendar.hasTradingDayCompleted(dayKey: extremes.dayKey, at: date, marketHours: marketHours) {
            finalizeTradingDay(personID: personID, dayKey: extremes.dayKey, extremes: extremes)
            markFirstTradingDayCompleteIfNeeded(personID: personID, completedDayKey: extremes.dayKey, at: date)
            clearUnfinishedDayExtremes(for: personID)
        }

        return snapshot(for: personID)
    }

    private func rolloverDayIfNeeded(personID: String, to newDayKey: String, at date: Date) {
        guard let previousDayKey = currentDayKeyByPerson[personID], previousDayKey != newDayKey else {
            return
        }

        if let extremes = dayExtremesByPerson[personID], extremes.dayKey == previousDayKey {
            finalizeTradingDay(personID: personID, dayKey: previousDayKey, extremes: extremes)
            markFirstTradingDayCompleteIfNeeded(personID: personID, completedDayKey: previousDayKey, at: date)
        }

        clearUnfinishedDayExtremes(for: personID)
    }

    private func finalizeTradingDay(personID: String, dayKey: String, extremes: DayExtremes) {
        guard extremes.hadQuotableSample else { return }

        var completed = completedDayKeysByPerson[personID] ?? []
        guard !completed.contains(dayKey) else { return }
        completed.insert(dayKey)
        completedDayKeysByPerson[personID] = completed

        updateBestIfNeeded(personID: personID, amount: extremes.peak, date: extremes.lastSampleDate)
        updateWorstIfNeeded(personID: personID, amount: extremes.trough, date: extremes.lastSampleDate)
    }

    private func markFirstTradingDayCompleteIfNeeded(personID: String, completedDayKey: String, at date: Date) {
        guard !defaults.bool(forKey: Self.firstDayCompleteKey(personID)) else { return }
        guard quotableSampleDayKeysByPerson[personID]?.contains(completedDayKey) == true else {
            return
        }

        // A later ET calendar day implies the prior trading day is complete,
        // even if the market is open again on the new day (hasTradingDayCompleted would
        // otherwise return false because isMarketOpen is true).
        let nowDayKey = calendar.dayKey(for: date)
        let tradingDayIsComplete: Bool
        if completedDayKey < nowDayKey {
            tradingDayIsComplete = true
        } else {
            tradingDayIsComplete = calendar.hasTradingDayCompleted(
                dayKey: completedDayKey,
                at: date,
                marketHours: marketHours
            )
        }
        guard tradingDayIsComplete else { return }

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

    // MARK: - Unfinished day extremes persistence

    private func loadUnfinishedDayExtremesIfNeeded(for personID: String) {
        guard !loadedUnfinishedPersonIDs.contains(personID) else { return }
        loadedUnfinishedPersonIDs.insert(personID)

        guard let extremes = loadUnfinishedDayExtremes(for: personID) else { return }

        dayExtremesByPerson[personID] = extremes
        currentDayKeyByPerson[personID] = extremes.dayKey
        if extremes.hadQuotableSample {
            var sampledDays = quotableSampleDayKeysByPerson[personID] ?? []
            sampledDays.insert(extremes.dayKey)
            quotableSampleDayKeysByPerson[personID] = sampledDays
        }
    }

    private func loadUnfinishedDayExtremes(for personID: String) -> DayExtremes? {
        guard let data = defaults.data(forKey: Self.unfinishedKey(personID)),
              let extremes = try? JSONDecoder().decode(DayExtremes.self, from: data) else {
            return nil
        }
        return extremes
    }

    private func persistUnfinishedDayExtremes(_ extremes: DayExtremes, for personID: String) {
        guard let data = try? JSONEncoder().encode(extremes) else { return }
        defaults.set(data, forKey: Self.unfinishedKey(personID))
    }

    private func clearUnfinishedDayExtremes(for personID: String) {
        dayExtremesByPerson.removeValue(forKey: personID)
        defaults.removeObject(forKey: Self.unfinishedKey(personID))
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

    private static func unfinishedKey(_ personID: String) -> String {
        "dailyRecordUnfinished_\(personID)"
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "dailyRecordBest_\(personID)")
        defaults.removeObject(forKey: "dailyRecordWorst_\(personID)")
        defaults.removeObject(forKey: "dailyRecordInstallDay_\(personID)")
        defaults.removeObject(forKey: "dailyRecordFirstDayComplete_\(personID)")
        defaults.removeObject(forKey: "dailyRecordUnfinished_\(personID)")
    }
}

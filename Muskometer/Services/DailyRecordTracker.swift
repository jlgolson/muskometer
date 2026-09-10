import Foundation

/// Tracks best and worst daily paper gains since install, keyed by `personID`.
@MainActor
final class DailyRecordTracker {
    struct Snapshot: Equatable, Sendable {
        let bestRecord: DailyGainRecord?
        let worstRecord: DailyGainRecord?
        let hasCompletedFirstTradingDay: Bool
    }

    struct FinalizedTradingDay: Equatable, Sendable, Codable {
        let dayKey: String
        let closeGain: Double
        let peak: Double
        let trough: Double
        let date: Date
    }

    private struct PersistedRecord: Codable, Equatable {
        let amount: Double
        let date: Date
    }

    /// In-progress peak/trough for the current ET trading day (memory + UserDefaults).
    private struct DayExtremes: Equatable, Codable {
        var peak: Double
        var trough: Double
        var lastSampleGain: Double
        var lastSampleDate: Date
        var dayKey: String
        var hadQuotableSample: Bool

        init(
            peak: Double,
            trough: Double,
            lastSampleGain: Double,
            lastSampleDate: Date,
            dayKey: String,
            hadQuotableSample: Bool
        ) {
            self.peak = peak
            self.trough = trough
            self.lastSampleGain = lastSampleGain
            self.lastSampleDate = lastSampleDate
            self.dayKey = dayKey
            self.hadQuotableSample = hadQuotableSample
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            peak = try container.decode(Double.self, forKey: .peak)
            trough = try container.decode(Double.self, forKey: .trough)
            lastSampleDate = try container.decode(Date.self, forKey: .lastSampleDate)
            dayKey = try container.decode(String.self, forKey: .dayKey)
            hadQuotableSample = try container.decode(Bool.self, forKey: .hadQuotableSample)
            lastSampleGain = try container.decodeIfPresent(Double.self, forKey: .lastSampleGain) ?? peak
        }
    }

    private let defaults: UserDefaults
    private let calendar: TradingDayCalendar
    private let marketHours: any MarketHoursServiceProtocol

    private var dayExtremesByPerson: [String: DayExtremes] = [:]
    private var currentDayKeyByPerson: [String: String] = [:]
    /// Last finalized trading day per person — avoids unbounded day-key Sets.
    private var lastCompletedDayKeyByPerson: [String: String] = [:]
    /// Persons whose unfinished extremes have been loaded from UserDefaults this runtime session.
    private var loadedUnfinishedPersonIDs: Set<String> = []
    private var pendingFinalizedDayByPerson: [String: FinalizedTradingDay] = [:]
    /// Persons whose pending finalized day has been loaded from UserDefaults this runtime session.
    private var loadedPendingFinalizedPersonIDs: Set<String> = []

    init(
        defaults: UserDefaults = .standard,
        calendar: TradingDayCalendar = TradingDayCalendar(),
        marketHours: any MarketHoursServiceProtocol = MarketHoursService()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.marketHours = marketHours
    }

    /// Clears in-memory day/pending state for `personID`. Persisted pending finalized
    /// days remain on disk and reload on the next peek/update (durability across relaunch).
    func resetRuntimeState(for personID: String) {
        dayExtremesByPerson.removeValue(forKey: personID)
        currentDayKeyByPerson.removeValue(forKey: personID)
        lastCompletedDayKeyByPerson.removeValue(forKey: personID)
        loadedUnfinishedPersonIDs.remove(personID)
        loadedPendingFinalizedPersonIDs.remove(personID)
        pendingFinalizedDayByPerson.removeValue(forKey: personID)
    }

    /// Returns the most recent finalized trading day without clearing it (for delivery-then-consume).
    func peekPendingFinalizedDay(for personID: String) -> FinalizedTradingDay? {
        loadPendingFinalizedDayIfNeeded(for: personID)
        return pendingFinalizedDayByPerson[personID]
    }

    /// Returns and clears the most recent finalized trading day for notification side effects.
    func consumePendingFinalizedDay(for personID: String) -> FinalizedTradingDay? {
        loadPendingFinalizedDayIfNeeded(for: personID)
        let day = pendingFinalizedDayByPerson.removeValue(forKey: personID)
        clearPersistedPendingFinalizedDay(for: personID)
        return day
    }

    /// Acknowledges only the exact delivered value, preserving any newer pending observation.
    @discardableResult
    func consumePendingFinalizedDay(for personID: String, matching day: FinalizedTradingDay) -> FinalizedTradingDay? {
        loadPendingFinalizedDayIfNeeded(for: personID)
        guard pendingFinalizedDayByPerson[personID] == day else { return nil }
        return consumePendingFinalizedDay(for: personID)
    }

    /// Advances the session clock using only real, persisted observations. No quote is invented.
    @discardableResult
    func advanceClock(personID: String, at date: Date = .now) -> Snapshot {
        loadUnfinishedDayExtremesIfNeeded(for: personID)
        loadPendingFinalizedDayIfNeeded(for: personID)
        let dayKey = calendar.dayKey(for: date)
        guard (currentDayKeyByPerson[personID] ?? dayKey) <= dayKey else {
            return snapshot(for: personID)
        }
        currentDayKeyByPerson[personID] = dayKey
        finalizeCompletedDayIfNeeded(personID: personID, at: date)
        return snapshot(for: personID)
    }

    /// Restores a pending finalized day after a failed notification delivery (does not clear lastCompleted).
    func restorePendingFinalizedDay(_ day: FinalizedTradingDay, for personID: String) {
        storePendingFinalizedDay(day, for: personID)
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
        loadPendingFinalizedDayIfNeeded(for: personID)

        let dayKey = calendar.dayKey(for: date)
        guard (currentDayKeyByPerson[personID] ?? dayKey) <= dayKey else {
            return snapshot(for: personID)
        }

        if defaults.string(forKey: Self.installDayKey(personID)) == nil {
            defaults.set(dayKey, forKey: Self.installDayKey(personID))
        }

        // Complete an earlier session before accepting the new session's first sample.
        if let extremes = dayExtremesByPerson[personID], extremes.dayKey < dayKey {
            finalizeCompletedDayIfNeeded(personID: personID, at: date)
        }

        // Always track the ET day key so overnight/closed refreshes can roll over and
        // finalize prior days without inventing peak/trough from non-quotable gains.
        currentDayKeyByPerson[personID] = dayKey

        if isQuotable {
            var extremes = dayExtremesByPerson[personID] ?? DayExtremes(
                peak: paperGain,
                trough: paperGain,
                lastSampleGain: paperGain,
                lastSampleDate: date,
                dayKey: dayKey,
                hadQuotableSample: true
            )
            // If memory still holds a different day's extremes (should be rare after rollover), reseat.
            if extremes.dayKey != dayKey {
                extremes = DayExtremes(
                    peak: paperGain,
                    trough: paperGain,
                    lastSampleGain: paperGain,
                    lastSampleDate: date,
                    dayKey: dayKey,
                    hadQuotableSample: true
                )
            } else {
                extremes.peak = max(extremes.peak, paperGain)
                extremes.trough = min(extremes.trough, paperGain)
                extremes.lastSampleGain = paperGain
                extremes.lastSampleDate = date
                extremes.hadQuotableSample = true
            }
            dayExtremesByPerson[personID] = extremes
            persistUnfinishedDayExtremes(extremes, for: personID)
        }

        finalizeCompletedDayIfNeeded(personID: personID, at: date)
        return snapshot(for: personID)
    }

    private func finalizeCompletedDayIfNeeded(personID: String, at date: Date) {
        guard let extremes = dayExtremesByPerson[personID], extremes.hadQuotableSample,
              let dayStart = calendar.startOfDay(for: extremes.dayKey),
              let regularClose = marketHours.regularCloseDate(on: dayStart),
              date >= regularClose else { return }
        // A prior session is complete even while the next day's regular session is open.
        finalizeTradingDay(personID: personID, dayKey: extremes.dayKey, extremes: extremes)
        markFirstTradingDayCompleteIfNeeded(personID: personID, completedDayKey: extremes.dayKey, at: date)
        clearUnfinishedDayExtremes(for: personID)
    }

    private func finalizeTradingDay(personID: String, dayKey: String, extremes: DayExtremes) {
        guard extremes.hadQuotableSample else { return }
        guard (lastCompletedDayKeyByPerson[personID] ?? "") < dayKey else { return }
        lastCompletedDayKeyByPerson[personID] = dayKey

        updateBestIfNeeded(personID: personID, amount: extremes.peak, date: extremes.lastSampleDate)
        updateWorstIfNeeded(personID: personID, amount: extremes.trough, date: extremes.lastSampleDate)
        storePendingFinalizedDay(
            FinalizedTradingDay(
                dayKey: dayKey,
                closeGain: extremes.lastSampleGain,
                peak: extremes.peak,
                trough: extremes.trough,
                date: extremes.lastSampleDate
            ),
            for: personID
        )
    }

    private func markFirstTradingDayCompleteIfNeeded(personID: String, completedDayKey: String, at date: Date) {
        guard !defaults.bool(forKey: Self.firstDayCompleteKey(personID)) else { return }
        // Caller only finalizes days that had quotable samples (`extremes.hadQuotableSample`).

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

    // MARK: - Pending finalized day persistence (day-close notification retry across relaunch)

    private func loadPendingFinalizedDayIfNeeded(for personID: String) {
        guard !loadedPendingFinalizedPersonIDs.contains(personID) else { return }
        loadedPendingFinalizedPersonIDs.insert(personID)

        guard pendingFinalizedDayByPerson[personID] == nil else { return }
        guard let data = defaults.data(forKey: Self.pendingFinalizedKey(personID)),
              let day = try? JSONDecoder().decode(FinalizedTradingDay.self, from: data) else {
            return
        }
        pendingFinalizedDayByPerson[personID] = day
        lastCompletedDayKeyByPerson[personID] = day.dayKey
    }

    private func storePendingFinalizedDay(_ day: FinalizedTradingDay, for personID: String) {
        pendingFinalizedDayByPerson[personID] = day
        loadedPendingFinalizedPersonIDs.insert(personID)
        guard let data = try? JSONEncoder().encode(day) else {
            #if DEBUG
            assertionFailure("DailyRecordTracker: failed to encode pending finalized day")
            #endif
            return
        }
        defaults.set(data, forKey: Self.pendingFinalizedKey(personID))
    }

    private func clearPersistedPendingFinalizedDay(for personID: String) {
        defaults.removeObject(forKey: Self.pendingFinalizedKey(personID))
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

    private static func pendingFinalizedKey(_ personID: String) -> String {
        "dailyRecordPendingFinalized_\(personID)"
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "dailyRecordBest_\(personID)")
        defaults.removeObject(forKey: "dailyRecordWorst_\(personID)")
        defaults.removeObject(forKey: "dailyRecordInstallDay_\(personID)")
        defaults.removeObject(forKey: "dailyRecordFirstDayComplete_\(personID)")
        defaults.removeObject(forKey: "dailyRecordUnfinished_\(personID)")
        defaults.removeObject(forKey: "dailyRecordPendingFinalized_\(personID)")
    }
}

import Foundation

/// Tracks recently shown comparison lines so captions do not repeat within seven days.
struct ComparisonHistoryStore {
    private struct HistoryEntry: Codable, Equatable {
        let entryID: String
        let dayKey: String
    }

    private let defaults: UserDefaults
    private let calendar: TradingDayCalendar
    private let retentionDays: Int

    init(
        defaults: UserDefaults = .standard,
        calendar: TradingDayCalendar = TradingDayCalendar(),
        retentionDays: Int = 7
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.retentionDays = retentionDays
    }

    func recentlyUsedEntryIDs(personID: String, on date: Date = .now) -> Set<String> {
        let currentDayKey = calendar.dayKey(for: date)
        guard let currentDay = calendar.startOfDay(for: currentDayKey) else { return [] }

        let history = loadHistory(personID: personID)
        var used: Set<String> = []

        for entry in history {
            guard let day = calendar.startOfDay(for: entry.dayKey) else { continue }
            let dayDelta = calendar.calendar.dateComponents([.day], from: day, to: currentDay).day ?? 0
            if dayDelta >= 0 && dayDelta < retentionDays {
                used.insert(entry.entryID)
            }
        }

        return used
    }

    mutating func recordUse(entryID: String, personID: String, on date: Date = .now) {
        let dayKey = calendar.dayKey(for: date)
        var history = loadHistory(personID: personID)
        history.append(HistoryEntry(entryID: entryID, dayKey: dayKey))
        history = prune(history, relativeTo: date)
        saveHistory(history, personID: personID)
    }

    static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey(personID: personID))
        if personID == TrackedPersonProfile.musk.id {
            defaults.removeObject(forKey: legacyStorageKey)
        }
    }

    private func loadHistory(personID: String) -> [HistoryEntry] {
        Self.migrateLegacyIfNeeded(defaults: defaults, personID: personID)

        guard let data = defaults.data(forKey: Self.storageKey(personID: personID)),
              let history = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        return history
    }

    private func saveHistory(_ history: [HistoryEntry], personID: String) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.storageKey(personID: personID))
    }

    private func prune(_ history: [HistoryEntry], relativeTo date: Date) -> [HistoryEntry] {
        let currentDayKey = calendar.dayKey(for: date)
        guard let currentDay = calendar.startOfDay(for: currentDayKey) else { return history }

        return history.filter { entry in
            guard let day = calendar.startOfDay(for: entry.dayKey) else { return false }
            let dayDelta = calendar.calendar.dateComponents([.day], from: day, to: currentDay).day ?? 0
            return dayDelta >= 0 && dayDelta < retentionDays
        }
    }

    private static let legacyStorageKey = "comparisonHistoryEntries"

    private static func storageKey(personID: String) -> String {
        "comparisonHistoryEntries_\(personID)"
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
}
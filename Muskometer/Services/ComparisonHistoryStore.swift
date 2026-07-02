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

    func recentlyUsedEntryIDs(on date: Date = .now) -> Set<String> {
        let currentDayKey = calendar.dayKey(for: date)
        guard let currentDay = calendar.startOfDay(for: currentDayKey) else { return [] }

        let history = loadHistory()
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

    mutating func recordUse(entryID: String, on date: Date = .now) {
        let dayKey = calendar.dayKey(for: date)
        var history = loadHistory()
        history.append(HistoryEntry(entryID: entryID, dayKey: dayKey))
        history = prune(history, relativeTo: date)
        saveHistory(history)
    }

    private func loadHistory() -> [HistoryEntry] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let history = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        return history
    }

    private func saveHistory(_ history: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.storageKey)
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

    private static let storageKey = "comparisonHistoryEntries"
}
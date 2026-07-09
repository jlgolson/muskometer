import Foundation

/// Maps instants to US equity trading-day keys in Eastern Time (`yyyy-MM-dd`).
struct TradingDayCalendar: Sendable {
    let calendar: Calendar
    let timeZone: TimeZone

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = TimeZone(identifier: "America/New_York") ?? .current
    ) {
        var configured = calendar
        configured.timeZone = timeZone
        self.calendar = configured
        self.timeZone = timeZone
    }

    /// `DateFormatter` is not thread-safe; create a fresh instance per call with fixed locale/format.
    private func makeDayKeyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        return formatter
    }

    /// Returns the Eastern calendar day key for `date`.
    func dayKey(for date: Date) -> String {
        makeDayKeyFormatter().string(from: date)
    }

    func isSameTradingDay(_ lhs: Date, _ rhs: Date) -> Bool {
        dayKey(for: lhs) == dayKey(for: rhs)
    }

    /// Start of the Eastern calendar day for `dayKey`.
    func startOfDay(for dayKey: String) -> Date? {
        guard let day = makeDayKeyFormatter().date(from: dayKey) else { return nil }
        return calendar.startOfDay(for: day)
    }

    /// Builds an Eastern-time instant on the given trading day.
    func date(on dayKey: String, hour: Int, minute: Int, second: Int = 0) -> Date? {
        guard let day = startOfDay(for: dayKey) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timeZone
        return calendar.date(from: components)
    }

    /// A trading day is complete once the regular session has ended for that Eastern day
    /// (16:00 ET, or early close when `marketHours` models it). Daily best/worst finalize at RTH end.
    func hasTradingDayCompleted(dayKey: String, at date: Date, marketHours: any MarketHoursServiceProtocol) -> Bool {
        guard let dayStart = startOfDay(for: dayKey),
              let regularClose = marketHours.regularCloseDate(on: dayStart) else {
            return false
        }
        return date >= regularClose && !marketHours.isMarketOpen(at: date)
    }

}
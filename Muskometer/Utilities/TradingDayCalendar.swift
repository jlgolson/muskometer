import Foundation

/// Maps instants to US equity trading-day keys in Eastern Time (`yyyy-MM-dd`).
struct TradingDayCalendar: Sendable {
    let calendar: Calendar
    let timeZone: TimeZone

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        calendar: Calendar = .current,
        timeZone: TimeZone = TimeZone(identifier: "America/New_York") ?? .current
    ) {
        var configured = calendar
        configured.timeZone = timeZone
        self.calendar = configured
        self.timeZone = timeZone
    }

    /// Returns the Eastern calendar day key for `date`.
    func dayKey(for date: Date) -> String {
        let formatter = Self.dayKeyFormatter
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    func isSameTradingDay(_ lhs: Date, _ rhs: Date) -> Bool {
        dayKey(for: lhs) == dayKey(for: rhs)
    }

    /// Start of the Eastern calendar day for `dayKey`.
    func startOfDay(for dayKey: String) -> Date? {
        let formatter = Self.dayKeyFormatter
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        guard let day = formatter.date(from: dayKey) else { return nil }
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

    /// A trading day is complete once regular market hours have ended for that Eastern day.
    func hasTradingDayCompleted(dayKey: String, at date: Date, marketHours: any MarketHoursServiceProtocol) -> Bool {
        guard let marketClose = self.date(on: dayKey, hour: 16, minute: 0) else { return false }
        return date >= marketClose && !marketHours.isMarketOpen(at: date)
    }

}
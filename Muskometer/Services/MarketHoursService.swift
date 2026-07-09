import Foundation

enum TradingSession: Equatable, Sendable {
    case preMarket
    case regular
    case postMarket
    case closed

    var isQuotable: Bool {
        self != .closed
    }
}

protocol MarketHoursServiceProtocol: Sendable {
    func currentSession(at date: Date) -> TradingSession
    func isQuotable(at date: Date) -> Bool
    func isMarketOpen(at date: Date) -> Bool
    func nextOpenDate(from date: Date) -> Date?
    func lastMarketClose(from date: Date) -> Date?
}

extension MarketHoursServiceProtocol {
    func currentSession() -> TradingSession {
        currentSession(at: .now)
    }

    func isQuotable() -> Bool {
        isQuotable(at: .now)
    }

    func isMarketOpen() -> Bool {
        isMarketOpen(at: .now)
    }

    func nextOpenDate() -> Date? {
        nextOpenDate(from: .now)
    }

    func lastMarketClose() -> Date? {
        lastMarketClose(from: .now)
    }
}

struct MarketHoursService: MarketHoursServiceProtocol {
    private enum SessionMinutes {
        static let preMarketOpen = 4 * 60
        static let regularOpen = 9 * 60 + 30
        /// Standard regular-session close (4:00 PM ET).
        static let regularClose = 16 * 60
        /// Typical NYSE early close (1:00 PM ET).
        static let earlyClose = 13 * 60
        static let postMarketClose = 20 * 60
    }

    /// NYSE early-close days → regular-session end as minutes since midnight ET.
    /// Covers the same years as the full-holiday set (2026–2027). Extend annually.
    /// Source: NYSE Holidays & Trading Hours (day after Thanksgiving, Christmas Eve when applicable).
    private static let earlyCloses: [String: Int] = [
        "2026-11-27": SessionMinutes.earlyClose, // day after Thanksgiving
        "2026-12-24": SessionMinutes.earlyClose, // Christmas Eve
        "2027-11-26": SessionMinutes.earlyClose, // day after Thanksgiving
        // 2027-12-24 is a full holiday (Christmas observed); no Christmas Eve early close in 2027.
    ]

    private let calendar: Calendar
    private let timeZone: TimeZone

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = TimeZone(identifier: "America/New_York") ?? .current
    ) {
        var configured = calendar
        configured.timeZone = timeZone
        self.calendar = configured
        self.timeZone = timeZone
    }

    func currentSession(at date: Date = .now) -> TradingSession {
        guard isTradingDay(date) else { return .closed }

        let minutes = minutesSinceMidnight(on: date)
        let regularClose = regularCloseMinutes(on: date)

        if minutes >= SessionMinutes.preMarketOpen, minutes < SessionMinutes.regularOpen {
            return .preMarket
        }
        if minutes >= SessionMinutes.regularOpen, minutes < regularClose {
            return .regular
        }
        // Post-market runs from regular (or early) close until 20:00 ET.
        if minutes >= regularClose, minutes < SessionMinutes.postMarketClose {
            return .postMarket
        }
        return .closed
    }

    func isQuotable(at date: Date = .now) -> Bool {
        currentSession(at: date).isQuotable
    }

    func isMarketOpen(at date: Date = .now) -> Bool {
        currentSession(at: date) == .regular
    }

    func nextOpenDate(from date: Date = .now) -> Date? {
        if isQuotable(at: date) { return nil }

        if let preMarketOpen = preMarketOpen(on: date), date < preMarketOpen {
            return preMarketOpen
        }

        var day = calendar.startOfDay(for: date)

        for _ in 0..<10 {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            day = nextDay

            if let open = preMarketOpen(on: day) {
                return open
            }
        }

        return nil
    }

    func lastMarketClose(from date: Date) -> Date? {
        var day = calendar.startOfDay(for: date)

        if let close = marketCloseIfTradingDay(on: day), date >= close {
            return close
        }

        for _ in 0..<10 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else {
                return nil
            }
            day = previous
            if let close = marketCloseIfTradingDay(on: day) {
                return close
            }
        }

        return nil
    }

    private func isTradingDay(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard weekday != 1, weekday != 7 else { return false }
        return !isHoliday(date)
    }

    private func minutesSinceMidnight(on date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }

    /// Regular-session end in minutes since midnight ET (early close when applicable).
    private func regularCloseMinutes(on date: Date) -> Int {
        Self.earlyCloses[dayKey(for: date)] ?? SessionMinutes.regularClose
    }

    private func preMarketOpen(on day: Date) -> Date? {
        guard isTradingDay(day) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = 4
        components.minute = 0
        components.second = 0
        components.timeZone = timeZone

        return calendar.date(from: components)
    }

    private func marketCloseIfTradingDay(on day: Date) -> Date? {
        guard isTradingDay(day) else { return nil }

        let closeMinutes = regularCloseMinutes(on: day)
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = closeMinutes / 60
        components.minute = closeMinutes % 60
        components.second = 0
        components.timeZone = timeZone

        return calendar.date(from: components)
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func isHoliday(_ date: Date) -> Bool {
        // Minimal set — extend as needed.
        let holidays: Set<String> = [
            "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03",
            "2026-05-25", "2026-06-19", "2026-07-03", "2026-09-07",
            "2026-11-26", "2026-12-25",
            "2027-01-01", "2027-01-18", "2027-02-15", "2027-03-26",
            "2027-05-31", "2027-06-18", "2027-07-05", "2027-09-06",
            "2027-11-25", "2027-12-24"
        ]

        return holidays.contains(dayKey(for: date))
    }
}
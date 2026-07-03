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
        static let regularClose = 16 * 60
        static let postMarketClose = 20 * 60
    }

    private let calendar: Calendar
    private let timeZone: TimeZone

    init(
        calendar: Calendar = .current,
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

        if minutes >= SessionMinutes.preMarketOpen, minutes < SessionMinutes.regularOpen {
            return .preMarket
        }
        if minutes >= SessionMinutes.regularOpen, minutes < SessionMinutes.regularClose {
            return .regular
        }
        if minutes >= SessionMinutes.regularClose, minutes < SessionMinutes.postMarketClose {
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

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = 16
        components.minute = 0
        components.second = 0
        components.timeZone = timeZone

        return calendar.date(from: components)
    }

    private func isHoliday(_ date: Date) -> Bool {
        // Minimal set — extend as needed.
        let holidays: Set<String> = [
            "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03",
            "2026-05-25", "2026-06-19", "2026-07-03", "2026-09-07",
            "2026-11-26", "2026-12-25",
            "2027-01-01", "2027-01-18", "2027-02-15", "2027-04-02",
            "2027-05-31", "2027-06-18", "2027-07-05", "2027-09-06",
            "2027-11-25", "2027-12-24"
        ]

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        return holidays.contains(formatter.string(from: date))
    }
}
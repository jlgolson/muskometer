import Foundation

protocol MarketHoursServiceProtocol: Sendable {
    func isMarketOpen(at date: Date) -> Bool
    func nextOpenDate(from date: Date) -> Date?
}

extension MarketHoursServiceProtocol {
    func isMarketOpen() -> Bool {
        isMarketOpen(at: .now)
    }

    func nextOpenDate() -> Date? {
        nextOpenDate(from: .now)
    }
}

struct MarketHoursService: MarketHoursServiceProtocol {
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

    func isMarketOpen(at date: Date = .now) -> Bool {
        guard !isHoliday(date) else { return false }

        let weekday = calendar.component(.weekday, from: date)
        guard weekday != 1, weekday != 7 else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutes = hour * 60 + minute

        let openMinutes = 9 * 60 + 30
        let closeMinutes = 16 * 60

        return minutes >= openMinutes && minutes < closeMinutes
    }

    func nextOpenDate(from date: Date = .now) -> Date? {
        if isMarketOpen(at: date) { return nil }

        if let todayOpen = marketOpen(on: date), todayOpen > date {
            return todayOpen
        }

        var day = calendar.startOfDay(for: date)

        for _ in 0..<10 {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            day = nextDay

            if let open = marketOpen(on: day) {
                return open
            }
        }

        return nil
    }

    private func marketOpen(on day: Date) -> Date? {
        let weekday = calendar.component(.weekday, from: day)
        guard weekday != 1, weekday != 7, !isHoliday(day) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = 9
        components.minute = 30
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
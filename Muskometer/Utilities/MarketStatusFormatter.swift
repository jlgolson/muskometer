import Foundation

enum MarketStatusFormatter {
    static func asOfCloseLabel(
        for referenceDate: Date,
        marketHours: any MarketHoursServiceProtocol,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String? {
        guard let closeDate = marketHours.lastMarketClose(from: referenceDate) else { return nil }
        return asOfCloseLabel(closeDate: closeDate, timeZone: timeZone, locale: locale)
    }

    static func asOfCloseLabel(
        closeDate: Date,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        let time = formattedTime(closeDate, timeZone: timeZone, locale: locale)
        let date = formattedDate(closeDate, timeZone: timeZone, locale: locale)
        return "As of \(time) on \(date)"
    }

    static func asOfLiveLabel(
        date: Date,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        "As of \(formattedDateTime(date, timeZone: timeZone, locale: locale))"
    }

    static func nextOpenLabel(
        for openDate: Date,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "'Opens' EEE h:mm a zzz"
        return formatter.string(from: openDate)
    }

    private static func formattedTime(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a zzz"
        return formatter.string(from: date)
    }

    private static func formattedDate(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    private static func formattedDateTime(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, h:mm a zzz"
        return formatter.string(from: date)
    }
}
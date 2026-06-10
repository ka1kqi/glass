import Foundation

public enum ClockFormatter {
    /// Whether the locale (which reflects the user's system 12/24-hour
    /// setting when `.autoupdatingCurrent`) uses a 24-hour clock.
    public static func is24Hour(locale: Locale = .autoupdatingCurrent) -> Bool {
        let format = DateFormatter.dateFormat(
            fromTemplate: "j", options: 0, locale: locale) ?? "h"
        return !format.contains("a")
    }

    /// Lock-screen style time: "9:41" in 12-hour locales, "21:41" in 24-hour.
    public static func timeString(
        for date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = is24Hour(locale: locale) ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    /// Seconds until the next minute boundary (60 if exactly on one).
    public static func intervalToNextMinute(from date: Date) -> TimeInterval {
        let next = Calendar.current.nextDate(
            after: date,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime)!
        return next.timeIntervalSince(date)
    }
}

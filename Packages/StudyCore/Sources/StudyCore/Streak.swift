import Foundation

public struct StreakInfo: Equatable, Sendable {
    public let current: Int
    public let longest: Int

    public init(current: Int, longest: Int) {
        self.current = current
        self.longest = longest
    }
}

public enum Streak {
    public static func compute(studyDays: Set<Date>, today: Date, calendar: Calendar) -> StreakInfo {
        let days = Set(studyDays.map { calendar.startOfDay(for: $0) })
        func shifted(_ date: Date, by value: Int) -> Date {
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: value, to: date)!)
        }

        let todayStart = calendar.startOfDay(for: today)
        var cursor = days.contains(todayStart) ? todayStart : shifted(todayStart, by: -1)
        var current = 0
        while days.contains(cursor) {
            current += 1
            cursor = shifted(cursor, by: -1)
        }

        var longest = 0
        for runStart in days where !days.contains(shifted(runStart, by: -1)) {
            var length = 1
            var next = shifted(runStart, by: 1)
            while days.contains(next) {
                length += 1
                next = shifted(next, by: 1)
            }
            longest = max(longest, length)
        }
        return StreakInfo(current: current, longest: longest)
    }
}

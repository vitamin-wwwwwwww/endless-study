import Foundation

public enum Stats {
    public static func dailyTotals(_ sessions: [SessionRecord], calendar: Calendar) -> [Date: Int] {
        var totals: [Date: Int] = [:]
        for session in sessions {
            totals[calendar.startOfDay(for: session.startedAt), default: 0] += session.minutes
        }
        return totals
    }

    public static func totalMinutes(_ sessions: [SessionRecord]) -> Int {
        sessions.reduce(0) { $0 + $1.minutes }
    }

    public static func tagTotals(_ sessions: [SessionRecord]) -> [UUID?: Int] {
        var totals: [UUID?: Int] = [:]
        for session in sessions {
            totals[session.tagID, default: 0] += session.minutes
        }
        return totals
    }

    public static func distinctTagCount(_ sessions: [SessionRecord]) -> Int {
        Set(sessions.compactMap(\.tagID)).count
    }
}

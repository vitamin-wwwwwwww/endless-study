import Foundation

public enum Heatmap {
    public static func intensity(minutes: Int) -> Int {
        switch minutes {
        case ..<1: return 0
        case 1..<30: return 1
        case 30..<60: return 2
        case 60..<120: return 3
        default: return 4
        }
    }

    public static func weeks(endingOn today: Date, weekCount: Int = 26, calendar: Calendar) -> [[Date?]] {
        let todayStart = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: todayStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let thisWeekStart = calendar.date(byAdding: .day, value: -offset, to: todayStart)!

        return (0..<weekCount).map { column in
            let weekStart = calendar.date(byAdding: .day, value: -7 * (weekCount - 1 - column), to: thisWeekStart)!
            return (0..<7).map { row in
                let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: row, to: weekStart)!)
                return date > todayStart ? nil : date
            }
        }
    }
}

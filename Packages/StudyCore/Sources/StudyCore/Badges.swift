import Foundation

public struct BadgeStats: Equatable, Sendable {
    public var totalMinutes: Int
    public var longestStreak: Int
    public var sessionCount: Int
    public var distinctTagCount: Int
    public var maxDailyMinutes: Int
    public var level: Int

    public init(totalMinutes: Int, longestStreak: Int, sessionCount: Int,
                distinctTagCount: Int, maxDailyMinutes: Int, level: Int) {
        self.totalMinutes = totalMinutes
        self.longestStreak = longestStreak
        self.sessionCount = sessionCount
        self.distinctTagCount = distinctTagCount
        self.maxDailyMinutes = maxDailyMinutes
        self.level = level
    }
}

public enum BadgeCategory: Sendable {
    case totalMinutes, longestStreak, sessionCount, tagCount, dailyMinutes, level
}

public struct Badge: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: BadgeCategory
    public let threshold: Int

    public var conditionText: String {
        switch category {
        case .totalMinutes: return "累計 \(threshold / 60) 時間"
        case .longestStreak: return "\(threshold) 日連続"
        case .sessionCount: return "記録 \(threshold) 回"
        case .tagCount: return "タグ \(threshold) 種類"
        case .dailyMinutes: return "1 日 \(threshold / 60) 時間"
        case .level: return "レベル \(threshold)"
        }
    }

    public func isUnlocked(by stats: BadgeStats) -> Bool {
        let value: Int
        switch category {
        case .totalMinutes: value = stats.totalMinutes
        case .longestStreak: value = stats.longestStreak
        case .sessionCount: value = stats.sessionCount
        case .tagCount: value = stats.distinctTagCount
        case .dailyMinutes: value = stats.maxDailyMinutes
        case .level: value = stats.level
        }
        return value >= threshold
    }
}

public enum Badges {
    public static let all: [Badge] = [
        Badge(id: "time_1h", name: "はじめの一時間", category: .totalMinutes, threshold: 60),
        Badge(id: "time_10h", name: "十時間の壁", category: .totalMinutes, threshold: 600),
        Badge(id: "time_50h", name: "五十時間", category: .totalMinutes, threshold: 3_000),
        Badge(id: "time_100h", name: "百時間", category: .totalMinutes, threshold: 6_000),
        Badge(id: "time_500h", name: "五百時間", category: .totalMinutes, threshold: 30_000),
        Badge(id: "time_1000h", name: "千時間の達人", category: .totalMinutes, threshold: 60_000),

        Badge(id: "streak_3", name: "三日坊主卒業", category: .longestStreak, threshold: 3),
        Badge(id: "streak_7", name: "一週間", category: .longestStreak, threshold: 7),
        Badge(id: "streak_30", name: "一か月", category: .longestStreak, threshold: 30),
        Badge(id: "streak_100", name: "百日", category: .longestStreak, threshold: 100),
        Badge(id: "streak_365", name: "一年", category: .longestStreak, threshold: 365),

        Badge(id: "count_1", name: "最初の一歩", category: .sessionCount, threshold: 1),
        Badge(id: "count_10", name: "十回目", category: .sessionCount, threshold: 10),
        Badge(id: "count_100", name: "百回目", category: .sessionCount, threshold: 100),
        Badge(id: "count_1000", name: "千回目", category: .sessionCount, threshold: 1_000),

        Badge(id: "tags_3", name: "三刀流", category: .tagCount, threshold: 3),
        Badge(id: "tags_10", name: "博学", category: .tagCount, threshold: 10),

        Badge(id: "daily_3h", name: "集中の日", category: .dailyMinutes, threshold: 180),
        Badge(id: "daily_6h", name: "没頭の日", category: .dailyMinutes, threshold: 360),

        Badge(id: "level_5", name: "レベル 5", category: .level, threshold: 5),
        Badge(id: "level_10", name: "レベル 10", category: .level, threshold: 10),
        Badge(id: "level_25", name: "レベル 25", category: .level, threshold: 25),
        Badge(id: "level_50", name: "レベル 50", category: .level, threshold: 50),
    ]

    public static func unlockedIDs(for stats: BadgeStats) -> Set<String> {
        Set(all.filter { $0.isUnlocked(by: stats) }.map(\.id))
    }
}

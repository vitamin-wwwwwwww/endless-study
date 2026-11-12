import Foundation

public struct ProgressSnapshot: Equatable, Sendable {
    public let totalMinutes: Int
    public let totalXP: Int
    public let level: LevelProgress
    public let streak: StreakInfo
    public let todayMinutes: Int
    public let dailyTotals: [Date: Int]
    public let unlockedBadgeIDs: Set<String>
}

public enum StudyProgress {
    public static func snapshot(sessions: [SessionRecord], bonusXP: Int,
                                today: Date, calendar: Calendar) -> ProgressSnapshot {
        let daily = Stats.dailyTotals(sessions, calendar: calendar)
        let total = Stats.totalMinutes(sessions)
        let xp = total + bonusXP
        let level = Leveling.progress(forXP: xp)
        let studyDays = Set(daily.filter { $0.value >= 1 }.keys)
        let streak = Streak.compute(studyDays: studyDays, today: today, calendar: calendar)
        let stats = BadgeStats(
            totalMinutes: total,
            longestStreak: streak.longest,
            sessionCount: sessions.count,
            distinctTagCount: Stats.distinctTagCount(sessions),
            maxDailyMinutes: daily.values.max() ?? 0,
            level: level.level
        )
        return ProgressSnapshot(
            totalMinutes: total,
            totalXP: xp,
            level: level,
            streak: streak,
            todayMinutes: daily[calendar.startOfDay(for: today)] ?? 0,
            dailyTotals: daily,
            unlockedBadgeIDs: Badges.unlockedIDs(for: stats)
        )
    }
}

public struct RecordOutcome: Equatable, Sendable {
    public let xpGained: Int
    public let levelBefore: Int
    public let levelAfter: Int
    public let newBadgeIDs: [String]
    public let ticketsAwarded: Int

    public init(xpGained: Int, levelBefore: Int, levelAfter: Int, newBadgeIDs: [String], ticketsAwarded: Int) {
        self.xpGained = xpGained
        self.levelBefore = levelBefore
        self.levelAfter = levelAfter
        self.newBadgeIDs = newBadgeIDs
        self.ticketsAwarded = ticketsAwarded
    }

    public var leveledUp: Bool { levelAfter > levelBefore }
}

public enum RecordEvaluator {
    public static func outcome(existing: [SessionRecord], new: SessionRecord, bonusXP: Int,
                               today: Date, calendar: Calendar) -> RecordOutcome {
        let before = StudyProgress.snapshot(sessions: existing, bonusXP: bonusXP, today: today, calendar: calendar)
        let after = StudyProgress.snapshot(sessions: existing + [new], bonusXP: bonusXP, today: today, calendar: calendar)

        let newDay = calendar.startOfDay(for: new.startedAt)
        let qualifying = existing.filter {
            $0.minutes >= Gacha.minMinutesForTicket && calendar.startOfDay(for: $0.startedAt) == newDay
        }.count

        let gained = after.unlockedBadgeIDs.subtracting(before.unlockedBadgeIDs)
        return RecordOutcome(
            xpGained: new.minutes,
            levelBefore: before.level.level,
            levelAfter: after.level.level,
            newBadgeIDs: Badges.all.map(\.id).filter(gained.contains),
            ticketsAwarded: Gacha.ticketsAwarded(newSessionMinutes: new.minutes,
                                                 qualifyingSessionsAlreadyOnDay: qualifying)
        )
    }
}

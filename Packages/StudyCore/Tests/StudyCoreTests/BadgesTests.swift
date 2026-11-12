import XCTest
@testable import StudyCore

final class BadgesTests: XCTestCase {
    private func stats(total: Int = 0, streak: Int = 0, count: Int = 0,
                       tags: Int = 0, daily: Int = 0, level: Int = 1) -> BadgeStats {
        BadgeStats(totalMinutes: total, longestStreak: streak, sessionCount: count,
                   distinctTagCount: tags, maxDailyMinutes: daily, level: level)
    }

    func testCatalogHas23UniqueBadges() {
        XCTAssertEqual(Badges.all.count, 23)
        XCTAssertEqual(Set(Badges.all.map(\.id)).count, 23)
    }

    func testNothingUnlockedAtZero() {
        XCTAssertEqual(Badges.unlockedIDs(for: stats()), [])
    }

    func testTotalTimeBoundary() {
        XCTAssertFalse(Badges.unlockedIDs(for: stats(total: 59)).contains("time_1h"))
        XCTAssertTrue(Badges.unlockedIDs(for: stats(total: 60)).contains("time_1h"))
        XCTAssertEqual(Badges.unlockedIDs(for: stats(total: 60_000)),
                       ["time_1h", "time_10h", "time_50h", "time_100h", "time_500h", "time_1000h"])
    }

    func testEachCategoryBoundary() {
        XCTAssertEqual(Badges.unlockedIDs(for: stats(streak: 7)), ["streak_3", "streak_7"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(count: 10)), ["count_1", "count_10"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(tags: 3)), ["tags_3"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(daily: 180)), ["daily_3h"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(level: 5)), ["level_5"])
        XCTAssertEqual(Badges.unlockedIDs(for: stats(level: 4)), [])
    }

    func testConditionText() {
        XCTAssertEqual(Badges.all.first { $0.id == "time_10h" }?.conditionText, "累計 10 時間")
        XCTAssertEqual(Badges.all.first { $0.id == "streak_30" }?.conditionText, "30 日連続")
        XCTAssertEqual(Badges.all.first { $0.id == "count_100" }?.conditionText, "記録 100 回")
        XCTAssertEqual(Badges.all.first { $0.id == "tags_3" }?.conditionText, "タグ 3 種類")
        XCTAssertEqual(Badges.all.first { $0.id == "daily_3h" }?.conditionText, "1 日 3 時間")
        XCTAssertEqual(Badges.all.first { $0.id == "level_10" }?.conditionText, "レベル 10")
    }
}

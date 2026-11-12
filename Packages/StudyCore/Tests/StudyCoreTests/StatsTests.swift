import XCTest
@testable import StudyCore

final class StatsTests: XCTestCase {
    func testDailyTotalsGroupsByStartDay() {
        let sessions = [
            SessionRecord(startedAt: day(2026, 11, 10, hour: 9), minutes: 30),
            SessionRecord(startedAt: day(2026, 11, 10, hour: 20), minutes: 15),
            SessionRecord(startedAt: day(2026, 11, 11, hour: 8), minutes: 60),
        ]
        let totals = Stats.dailyTotals(sessions, calendar: utc)
        XCTAssertEqual(totals[utc.startOfDay(for: day(2026, 11, 10))], 45)
        XCTAssertEqual(totals[utc.startOfDay(for: day(2026, 11, 11))], 60)
        XCTAssertEqual(totals.count, 2)
    }

    func testSessionCrossingMidnightCountsOnStartDay() {
        let sessions = [SessionRecord(startedAt: day(2026, 11, 10, hour: 23), minutes: 120)]
        let totals = Stats.dailyTotals(sessions, calendar: utc)
        XCTAssertEqual(totals, [utc.startOfDay(for: day(2026, 11, 10)): 120])
    }

    func testTotalsAndTags() {
        let a = UUID(), b = UUID()
        let sessions = [
            SessionRecord(startedAt: day(2026, 11, 10), minutes: 30, tagID: a),
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 20, tagID: a),
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 10, tagID: b),
            SessionRecord(startedAt: day(2026, 11, 12), minutes: 5),
        ]
        XCTAssertEqual(Stats.totalMinutes(sessions), 65)
        XCTAssertEqual(Stats.tagTotals(sessions), [a: 50, b: 10, nil: 5])
        XCTAssertEqual(Stats.distinctTagCount(sessions), 2)
    }
}

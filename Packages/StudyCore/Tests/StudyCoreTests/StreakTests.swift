import XCTest
@testable import StudyCore

final class StreakTests: XCTestCase {
    private func days(_ list: [(Int, Int)]) -> Set<Date> {
        Set(list.map { day(2026, $0.0, $0.1) })
    }

    func testNoRecords() {
        XCTAssertEqual(Streak.compute(studyDays: [], today: day(2026, 11, 12), calendar: utc),
                       StreakInfo(current: 0, longest: 0))
    }

    func testStudiedTodayCountsToday() {
        let info = Streak.compute(studyDays: days([(11, 10), (11, 11), (11, 12)]),
                                  today: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(info, StreakInfo(current: 3, longest: 3))
    }

    func testNotYetStudiedTodayCountsFromYesterday() {
        let info = Streak.compute(studyDays: days([(11, 10), (11, 11)]),
                                  today: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(info.current, 2)
    }

    func testBrokenStreakIsZeroButLongestRemains() {
        let info = Streak.compute(studyDays: days([(11, 1), (11, 2), (11, 3), (11, 4), (11, 9)]),
                                  today: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(info, StreakInfo(current: 0, longest: 4))
    }

    func testStreakAcrossMonthBoundary() {
        let info = Streak.compute(studyDays: days([(10, 30), (10, 31), (11, 1)]),
                                  today: day(2026, 11, 1), calendar: utc)
        XCTAssertEqual(info, StreakInfo(current: 3, longest: 3))
    }
}

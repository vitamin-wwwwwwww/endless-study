import XCTest
@testable import StudyCore

final class ProgressTests: XCTestCase {
    private let today = day(2026, 11, 12)

    func testSnapshotCombinesEverything() {
        let sessions = [
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 60),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 8), minutes: 30),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 20), minutes: 10),
        ]
        let snapshot = StudyProgress.snapshot(sessions: sessions, bonusXP: 50, today: today, calendar: utc)
        XCTAssertEqual(snapshot.totalMinutes, 100)
        XCTAssertEqual(snapshot.totalXP, 150)
        XCTAssertEqual(snapshot.level, LevelProgress(level: 2, xpIntoLevel: 50, xpForNextLevel: 200))
        XCTAssertEqual(snapshot.streak, StreakInfo(current: 2, longest: 2))
        XCTAssertEqual(snapshot.todayMinutes, 40)
        XCTAssertEqual(snapshot.unlockedBadgeIDs, ["time_1h", "count_1"])
    }

    func testEmptySnapshot() {
        let snapshot = StudyProgress.snapshot(sessions: [], bonusXP: 0, today: today, calendar: utc)
        XCTAssertEqual(snapshot.totalXP, 0)
        XCTAssertEqual(snapshot.level.level, 1)
        XCTAssertEqual(snapshot.streak, StreakInfo(current: 0, longest: 0))
        XCTAssertEqual(snapshot.todayMinutes, 0)
    }

    func testFirstRecordOutcome() {
        let new = SessionRecord(startedAt: today, minutes: 60)
        let outcome = RecordEvaluator.outcome(existing: [], new: new, bonusXP: 0, today: today, calendar: utc)
        XCTAssertEqual(outcome, RecordOutcome(xpGained: 60, levelBefore: 1, levelAfter: 1,
                                              newBadgeIDs: ["time_1h", "count_1"], ticketsAwarded: 1))
        XCTAssertFalse(outcome.leveledUp)
    }

    func testLevelUpOutcome() {
        let existing = [SessionRecord(startedAt: day(2026, 11, 11), minutes: 90)]
        let new = SessionRecord(startedAt: today, minutes: 20)
        let outcome = RecordEvaluator.outcome(existing: existing, new: new, bonusXP: 0, today: today, calendar: utc)
        XCTAssertEqual(outcome.levelBefore, 1)
        XCTAssertEqual(outcome.levelAfter, 2)
        XCTAssertTrue(outcome.leveledUp)
        XCTAssertEqual(outcome.newBadgeIDs, [])
    }

    func testTicketCapCountsOnlyQualifyingSessionsOnSameDay() {
        let existing = [
            SessionRecord(startedAt: day(2026, 11, 12, hour: 6), minutes: 15),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 7), minutes: 15),
            SessionRecord(startedAt: day(2026, 11, 12, hour: 8), minutes: 5),
            SessionRecord(startedAt: day(2026, 11, 11), minutes: 60),
        ]
        let third = SessionRecord(startedAt: day(2026, 11, 12, hour: 9), minutes: 15)
        XCTAssertEqual(RecordEvaluator.outcome(existing: existing, new: third, bonusXP: 0,
                                               today: today, calendar: utc).ticketsAwarded, 1)
        let fourth = SessionRecord(startedAt: day(2026, 11, 12, hour: 10), minutes: 15)
        XCTAssertEqual(RecordEvaluator.outcome(existing: existing + [third], new: fourth, bonusXP: 0,
                                               today: today, calendar: utc).ticketsAwarded, 0)
    }

    func testShortSessionGivesNoTicket() {
        let new = SessionRecord(startedAt: today, minutes: 14)
        XCTAssertEqual(RecordEvaluator.outcome(existing: [], new: new, bonusXP: 0,
                                               today: today, calendar: utc).ticketsAwarded, 0)
    }
}

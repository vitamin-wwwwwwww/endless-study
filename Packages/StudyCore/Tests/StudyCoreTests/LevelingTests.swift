import XCTest
@testable import StudyCore

final class LevelingTests: XCTestCase {
    func testTotalXPToReachLevel() {
        XCTAssertEqual(Leveling.totalXP(toReach: 1), 0)
        XCTAssertEqual(Leveling.totalXP(toReach: 2), 100)
        XCTAssertEqual(Leveling.totalXP(toReach: 3), 300)
        XCTAssertEqual(Leveling.totalXP(toReach: 4), 600)
    }

    func testLevelBoundaries() {
        XCTAssertEqual(Leveling.level(forXP: 0), 1)
        XCTAssertEqual(Leveling.level(forXP: 99), 1)
        XCTAssertEqual(Leveling.level(forXP: 100), 2)
        XCTAssertEqual(Leveling.level(forXP: 299), 2)
        XCTAssertEqual(Leveling.level(forXP: 300), 3)
    }

    func testNegativeXPIsLevelOne() {
        XCTAssertEqual(Leveling.level(forXP: -5), 1)
    }

    func testProgressWithinLevel() {
        let p = Leveling.progress(forXP: 150)
        XCTAssertEqual(p, LevelProgress(level: 2, xpIntoLevel: 50, xpForNextLevel: 200))
        XCTAssertEqual(p.fraction, 0.25, accuracy: 0.0001)
    }
}

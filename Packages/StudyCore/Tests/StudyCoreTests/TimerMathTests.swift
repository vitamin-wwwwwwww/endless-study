import XCTest
@testable import StudyCore

final class TimerMathTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testRoundsUpToMinute() {
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(1)), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(60)), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(61)), 2)
    }

    func testClampsToRange() {
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(-500)), 1)
        XCTAssertEqual(TimerMath.elapsedMinutes(from: start, to: start.addingTimeInterval(13 * 3600)), 720)
    }
}

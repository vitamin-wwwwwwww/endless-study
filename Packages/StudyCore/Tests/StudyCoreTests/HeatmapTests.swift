import XCTest
@testable import StudyCore

final class HeatmapTests: XCTestCase {
    func testIntensityBuckets() {
        XCTAssertEqual(Heatmap.intensity(minutes: 0), 0)
        XCTAssertEqual(Heatmap.intensity(minutes: 1), 1)
        XCTAssertEqual(Heatmap.intensity(minutes: 29), 1)
        XCTAssertEqual(Heatmap.intensity(minutes: 30), 2)
        XCTAssertEqual(Heatmap.intensity(minutes: 59), 2)
        XCTAssertEqual(Heatmap.intensity(minutes: 60), 3)
        XCTAssertEqual(Heatmap.intensity(minutes: 119), 3)
        XCTAssertEqual(Heatmap.intensity(minutes: 120), 4)
    }

    func testWeeksGrid() {
        let weeks = Heatmap.weeks(endingOn: day(2026, 11, 12), calendar: utc)
        XCTAssertEqual(weeks.count, 26)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })

        let last = weeks[25]
        XCTAssertEqual(last[0], utc.startOfDay(for: day(2026, 11, 8)))
        XCTAssertEqual(last[4], utc.startOfDay(for: day(2026, 11, 12)))
        XCTAssertNil(last[5])
        XCTAssertNil(last[6])

        XCTAssertEqual(weeks[0][0], utc.startOfDay(for: day(2026, 5, 17)))
    }
}

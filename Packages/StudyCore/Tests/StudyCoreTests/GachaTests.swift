import XCTest
@testable import StudyCore

final class GachaTests: XCTestCase {
    func testCatalogCounts() {
        XCTAssertEqual(RewardCatalog.rewards(of: .n).count, 12)
        XCTAssertEqual(RewardCatalog.rewards(of: .r).count, 8)
        XCTAssertEqual(RewardCatalog.rewards(of: .sr).count, 4)
        XCTAssertEqual(RewardCatalog.rewards(of: .ssr).count, 2)
        XCTAssertEqual(Set(RewardCatalog.all.map(\.id)).count, 26)
    }

    func testThemesHaveColorAndTitlesDoNot() {
        for reward in RewardCatalog.all {
            XCTAssertEqual(reward.colorHex != nil, reward.kind == .theme, reward.id)
        }
    }

    func testRarityBoundaries() {
        XCTAssertEqual(Gacha.rarity(forRoll: 0), .n)
        XCTAssertEqual(Gacha.rarity(forRoll: 699), .n)
        XCTAssertEqual(Gacha.rarity(forRoll: 700), .r)
        XCTAssertEqual(Gacha.rarity(forRoll: 949), .r)
        XCTAssertEqual(Gacha.rarity(forRoll: 950), .sr)
        XCTAssertEqual(Gacha.rarity(forRoll: 994), .sr)
        XCTAssertEqual(Gacha.rarity(forRoll: 995), .ssr)
        XCTAssertEqual(Gacha.rarity(forRoll: 999), .ssr)
    }

    func testResultPicksItemWithinRarity() {
        let ssr = RewardCatalog.rewards(of: .ssr)
        let result = Gacha.result(rarityRoll: 999, itemRoll: 1, owned: [])
        XCTAssertEqual(result, GachaResult(reward: ssr[1], isDuplicate: false, bonusXP: 0))
    }

    func testDuplicateConvertsToBonusXP() {
        let first = RewardCatalog.rewards(of: .n)[0]
        let result = Gacha.result(rarityRoll: 0, itemRoll: 0, owned: [first.id])
        XCTAssertEqual(result, GachaResult(reward: first, isDuplicate: true, bonusXP: 10))
        XCTAssertEqual(Rarity.r.duplicateXP, 30)
        XCTAssertEqual(Rarity.sr.duplicateXP, 100)
        XCTAssertEqual(Rarity.ssr.duplicateXP, 500)
    }

    func testDrawDistribution() {
        var rng = SeededRNG(seed: 42)
        var counts: [Rarity: Int] = [:]
        let trials = 100_000
        for _ in 0..<trials {
            counts[Gacha.draw(owned: [], using: &rng).reward.rarity, default: 0] += 1
        }
        func rate(_ rarity: Rarity) -> Double { Double(counts[rarity] ?? 0) / Double(trials) }
        XCTAssertEqual(rate(.n), 0.70, accuracy: 0.01)
        XCTAssertEqual(rate(.r), 0.25, accuracy: 0.01)
        XCTAssertEqual(rate(.sr), 0.045, accuracy: 0.005)
        XCTAssertEqual(rate(.ssr), 0.005, accuracy: 0.002)
    }

    func testTicketsAwarded() {
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 14, qualifyingSessionsAlreadyOnDay: 0), 0)
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 15, qualifyingSessionsAlreadyOnDay: 0), 1)
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 60, qualifyingSessionsAlreadyOnDay: 2), 1)
        XCTAssertEqual(Gacha.ticketsAwarded(newSessionMinutes: 60, qualifyingSessionsAlreadyOnDay: 3), 0)
    }
}

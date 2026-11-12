import Foundation

public struct GachaResult: Equatable, Sendable {
    public let reward: Reward
    public let isDuplicate: Bool
    public let bonusXP: Int
}

public enum Gacha {
    public static let minMinutesForTicket = 15
    public static let dailyTicketCap = 3

    public static func rarity(forRoll roll: Int) -> Rarity {
        switch roll {
        case ..<700: return .n
        case ..<950: return .r
        case ..<995: return .sr
        default: return .ssr
        }
    }

    public static func result(rarityRoll: Int, itemRoll: Int, owned: Set<String>) -> GachaResult {
        let rarity = rarity(forRoll: rarityRoll)
        let pool = RewardCatalog.rewards(of: rarity)
        let reward = pool[itemRoll % pool.count]
        let isDuplicate = owned.contains(reward.id)
        return GachaResult(reward: reward, isDuplicate: isDuplicate, bonusXP: isDuplicate ? rarity.duplicateXP : 0)
    }

    public static func draw<G: RandomNumberGenerator>(owned: Set<String>, using rng: inout G) -> GachaResult {
        let rarityRoll = Int.random(in: 0..<1000, using: &rng)
        let itemRoll = Int.random(in: 0..<1000, using: &rng)
        return result(rarityRoll: rarityRoll, itemRoll: itemRoll, owned: owned)
    }

    public static func ticketsAwarded(newSessionMinutes: Int, qualifyingSessionsAlreadyOnDay: Int) -> Int {
        guard newSessionMinutes >= minMinutesForTicket else { return 0 }
        return qualifyingSessionsAlreadyOnDay < dailyTicketCap ? 1 : 0
    }
}

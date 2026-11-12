import Foundation

public struct LevelProgress: Equatable, Sendable {
    public let level: Int
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int

    public init(level: Int, xpIntoLevel: Int, xpForNextLevel: Int) {
        self.level = level
        self.xpIntoLevel = xpIntoLevel
        self.xpForNextLevel = xpForNextLevel
    }

    public var fraction: Double {
        xpForNextLevel > 0 ? Double(xpIntoLevel) / Double(xpForNextLevel) : 0
    }
}

public enum Leveling {
    public static func totalXP(toReach level: Int) -> Int {
        50 * level * (level - 1)
    }

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while totalXP(toReach: level + 1) <= xp { level += 1 }
        return level
    }

    public static func progress(forXP xp: Int) -> LevelProgress {
        let xp = max(0, xp)
        let level = level(forXP: xp)
        let base = totalXP(toReach: level)
        return LevelProgress(
            level: level,
            xpIntoLevel: xp - base,
            xpForNextLevel: totalXP(toReach: level + 1) - base
        )
    }
}

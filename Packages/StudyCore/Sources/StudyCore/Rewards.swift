import Foundation

public enum Rarity: Int, CaseIterable, Sendable {
    case n, r, sr, ssr

    public var label: String {
        switch self {
        case .n: return "N"
        case .r: return "R"
        case .sr: return "SR"
        case .ssr: return "SSR"
        }
    }

    public var duplicateXP: Int {
        switch self {
        case .n: return 10
        case .r: return 30
        case .sr: return 100
        case .ssr: return 500
        }
    }
}

public enum RewardKind: Sendable {
    case title, theme
}

public struct Reward: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let rarity: Rarity
    public let kind: RewardKind
    public let colorHex: String?
}

public enum RewardCatalog {
    private static func title(_ id: String, _ name: String, _ rarity: Rarity) -> Reward {
        Reward(id: id, name: name, rarity: rarity, kind: .title, colorHex: nil)
    }

    private static func theme(_ id: String, _ name: String, _ rarity: Rarity, _ hex: String) -> Reward {
        Reward(id: id, name: name, rarity: rarity, kind: .theme, colorHex: hex)
    }

    public static let all: [Reward] = [
        title("title_n_beginner", "かけだし", .n),
        title("title_n_morning", "朝型", .n),
        title("title_n_night", "夜ふかし", .n),
        title("title_n_steady", "こつこつ", .n),
        title("title_n_curious", "知りたがり", .n),
        title("title_n_desk", "机の住人", .n),
        title("title_n_notes", "メモ魔", .n),
        title("title_n_coffee", "コーヒー党", .n),
        theme("theme_n_sky", "そらいろ", .n, "#5AC8FA"),
        theme("theme_n_orange", "みかん", .n, "#FF9500"),
        theme("theme_n_pink", "さくら", .n, "#FF6B9A"),
        theme("theme_n_mint", "ミント", .n, "#00C7BE"),

        title("title_r_scholar", "努力家", .r),
        title("title_r_explorer", "探究者", .r),
        title("title_r_marathon", "長距離ランナー", .r),
        title("title_r_owl", "知恵のフクロウ", .r),
        title("title_r_polyglot", "多芸多才", .r),
        theme("theme_r_indigo", "藍", .r, "#5856D6"),
        theme("theme_r_crimson", "紅", .r, "#D7263D"),
        theme("theme_r_forest", "深緑", .r, "#1B7F5C"),

        title("title_sr_sage", "賢者", .sr),
        title("title_sr_unstoppable", "止まらない人", .sr),
        theme("theme_sr_gold", "黄金", .sr, "#D4A017"),
        theme("theme_sr_violet", "紫水晶", .sr, "#9B5DE5"),

        title("title_ssr_endless", "終わりなき学徒", .ssr),
        theme("theme_ssr_aurora", "オーロラ", .ssr, "#00E5A8"),
    ]

    public static func reward(id: String) -> Reward? {
        all.first { $0.id == id }
    }

    public static func rewards(of rarity: Rarity) -> [Reward] {
        all.filter { $0.rarity == rarity }
    }
}

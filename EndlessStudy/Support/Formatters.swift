import SwiftUI
import StudyCore

func formatMinutes(_ minutes: Int) -> String {
    let hours = minutes / 60
    let rest = minutes % 60
    if hours == 0 { return "\(rest)分" }
    if rest == 0 { return "\(hours)時間" }
    return "\(hours)時間\(rest)分"
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum TagPalette {
    static let colors = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF", "#5856D6", "#AF52DE"]
}

enum AppTheme {
    static let defaultHex = "#34C759"

    static func color(themeID: String?) -> Color {
        let hex = themeID.flatMap { RewardCatalog.reward(id: $0)?.colorHex } ?? defaultHex
        return Color(hex: hex)
    }
}

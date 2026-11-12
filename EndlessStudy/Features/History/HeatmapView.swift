import SwiftUI
import StudyCore

struct HeatmapView: View {
    let dailyTotals: [Date: Int]

    private let cell: CGFloat = 14
    private let spacing: CGFloat = 3

    var body: some View {
        let weeks = Heatmap.weeks(endingOn: .now, calendar: .current)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(weeks.indices, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            cellView(weeks[column][row])
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .defaultScrollAnchor(.trailing)
    }

    @ViewBuilder
    private func cellView(_ date: Date?) -> some View {
        if let date {
            let level = Heatmap.intensity(minutes: dailyTotals[date] ?? 0)
            RoundedRectangle(cornerRadius: 3)
                .fill(level == 0 ? AnyShapeStyle(Color.secondary.opacity(0.15))
                                 : AnyShapeStyle(TintShapeStyle().opacity(Double(level) * 0.25)))
                .frame(width: cell, height: cell)
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }
}

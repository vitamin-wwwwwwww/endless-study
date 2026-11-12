import SwiftUI
import StudyCore

struct ResultView: View {
    let outcome: RecordOutcome

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var appeared = false

    private var newBadges: [Badge] {
        Badges.all.filter { outcome.newBadgeIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("+\(outcome.xpGained) XP")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.tint)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)

            if outcome.leveledUp {
                VStack(spacing: 4) {
                    Text("レベルアップ！")
                        .font(.title2.bold())
                    Text("Lv \(outcome.levelBefore) → Lv \(outcome.levelAfter)")
                        .font(.title3)
                }
            }

            ForEach(newBadges) { badge in
                Label("バッジ獲得: \(badge.name)", systemImage: "rosette")
                    .font(.headline)
            }

            if outcome.ticketsAwarded > 0 {
                Label("ガチャ券 +\(outcome.ticketsAwarded)", systemImage: "ticket.fill")
                    .font(.headline)
            }

            Spacer()

            if outcome.ticketsAwarded > 0 {
                Button("ガチャを引きに行く") {
                    router.tab = .collection
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Button("閉じる") { dismiss() }
                .controlSize(.large)
        }
        .padding(32)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }
}

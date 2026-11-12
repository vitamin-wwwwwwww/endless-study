import SwiftUI
import SwiftData
import StudyCore

private struct DrawBox: Identifiable {
    let id = UUID()
    let result: GachaResult
}

struct CollectionView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [StudySession]
    @Query private var states: [PlayerState]
    @Query private var ownedRewards: [OwnedReward]

    @State private var draw: DrawBox?
    @State private var drawCount = 0
    @State private var errorMessage: String?

    private var tickets: Int { states.first?.gachaTickets ?? 0 }
    private var ownedIDs: Set<String> { Set(ownedRewards.map(\.rewardID)) }

    var body: some View {
        let unlocked = StudyProgress.snapshot(sessions: sessions.map(\.record), bonusXP: states.first?.bonusXP ?? 0,
                                         today: .now, calendar: .current).unlockedBadgeIDs
        NavigationStack {
            List {
                Section("ガチャ") {
                    HStack {
                        Label("ガチャ券 \(tickets) 枚", systemImage: "ticket.fill")
                        Spacer()
                        Button("引く", action: drawGacha)
                            .buttonStyle(.borderedProminent)
                            .disabled(tickets == 0)
                    }
                    Text("15 分以上の記録で 1 枚（1 日 3 枚まで）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("景品 \(ownedIDs.count) / \(RewardCatalog.all.count)") {
                    ForEach(RewardCatalog.all) { reward in
                        rewardRow(reward, owned: ownedIDs.contains(reward.id))
                    }
                }

                Section("バッジ \(unlocked.count) / \(Badges.all.count)") {
                    ForEach(Badges.all) { badge in
                        let isUnlocked = unlocked.contains(badge.id)
                        HStack {
                            Image(systemName: isUnlocked ? "rosette" : "lock.fill")
                                .foregroundStyle(isUnlocked ? AnyShapeStyle(TintShapeStyle()) : AnyShapeStyle(Color.secondary))
                            VStack(alignment: .leading) {
                                Text(isUnlocked ? badge.name : "？？？")
                                Text(badge.conditionText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("コレクション")
        }
        .sensoryFeedback(.impact, trigger: drawCount)
        .sheet(item: $draw) { box in
            DrawResultView(result: box.result)
                .presentationDetents([.medium])
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func rewardRow(_ reward: Reward, owned: Bool) -> some View {
        let state = states.first
        let isEquipped = reward.kind == .title ? state?.equippedTitleID == reward.id
                                               : state?.equippedThemeID == reward.id
        return Button {
            toggleEquip(reward)
        } label: {
            HStack {
                Text(reward.rarity.label)
                    .font(.caption.bold())
                    .frame(width: 36)
                if let hex = reward.colorHex {
                    Circle()
                        .fill(owned ? Color(hex: hex) : Color.secondary.opacity(0.3))
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "textformat")
                        .frame(width: 16)
                }
                Text(owned ? reward.name : "？？？")
                Spacer()
                if isEquipped {
                    Text("装備中")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(owned ? Color.primary : Color.secondary)
        .disabled(!owned)
    }

    private func drawGacha() {
        do {
            if let result = try RecordService(context: context).drawGacha() {
                drawCount += 1
                draw = DrawBox(result: result)
            }
        } catch {
            errorMessage = "ガチャに失敗しました。券は消費されていません。"
        }
    }

    private func toggleEquip(_ reward: Reward) {
        do {
            let state = try RecordService(context: context).playerState()
            switch reward.kind {
            case .title:
                state.equippedTitleID = state.equippedTitleID == reward.id ? nil : reward.id
            case .theme:
                state.equippedThemeID = state.equippedThemeID == reward.id ? nil : reward.id
            }
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "変更に失敗しました。"
        }
    }
}

private struct DrawResultView: View {
    let result: GachaResult

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    private var rarityColor: Color {
        switch result.reward.rarity {
        case .n: return .gray
        case .r: return .blue
        case .sr: return .purple
        case .ssr: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(result.reward.rarity.label)
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(rarityColor)
                .scaleEffect(revealed ? 1 : 0.2)
                .rotationEffect(.degrees(revealed ? 0 : -180))
            Text(result.reward.name)
                .font(.title.bold())
                .opacity(revealed ? 1 : 0)
            Text(result.reward.kind == .title ? "称号" : "テーマ色")
                .foregroundStyle(.secondary)
            if result.isDuplicate {
                Text("もう持っている！ +\(result.bonusXP) XP")
                    .font(.headline)
            }
            Button("OK") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { revealed = true }
        }
        .sensoryFeedback(.success, trigger: revealed)
    }
}

import SwiftUI
import SwiftData
import StudyCore

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StudySession.startedAt, order: .reverse) private var sessions: [StudySession]
    @Query(sort: \Tag.createdAt) private var tags: [Tag]

    @State private var editing: StudySession?
    @State private var errorMessage: String?

    var body: some View {
        let records = sessions.map(\.record)
        let tagTotals = Stats.tagTotals(records)
        NavigationStack {
            List {
                Section("直近 26 週間") {
                    HeatmapView(dailyTotals: Stats.dailyTotals(records, calendar: .current))
                }

                Section("タグ別累計") {
                    ForEach(tags) { tag in
                        HStack {
                            Circle().fill(Color(hex: tag.colorHex)).frame(width: 12, height: 12)
                            Text(tag.name)
                            Spacer()
                            Text(formatMinutes(tagTotals[tag.id] ?? 0))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets.map { tags[$0] })
                    }
                    if let untagged = tagTotals[UUID?.none] {
                        HStack {
                            Circle().fill(Color.secondary).frame(width: 12, height: 12)
                            Text("タグなし")
                            Spacer()
                            Text(formatMinutes(untagged))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("履歴") {
                    if sessions.isEmpty {
                        Text("まだ記録がありません")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { session in
                        Button {
                            editing = session
                        } label: {
                            row(session)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        delete(offsets.map { sessions[$0] })
                    }
                }
            }
            .navigationTitle("記録")
        }
        .sheet(item: $editing) { session in
            SessionFormView(mode: .edit(session))
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

    private func row(_ session: StudySession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                    if let tag = session.tag {
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color(hex: tag.colorHex).opacity(0.25), in: Capsule())
                    }
                }
                if !session.memo.isEmpty {
                    Text(session.memo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(formatMinutes(session.minutes))
                .font(.headline)
        }
    }

    private func delete<T: PersistentModel>(_ models: [T]) {
        for model in models {
            context.delete(model)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "削除に失敗しました。"
        }
    }
}

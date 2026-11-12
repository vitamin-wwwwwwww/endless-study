import SwiftUI
import SwiftData
import StudyCore

enum SessionFormMode {
    case timer(startedAt: Date, minutes: Int)
    case manual
    case edit(StudySession)
}

struct SessionFormView: View {
    let mode: SessionFormMode
    let onSaved: (RecordOutcome?) -> Void
    let onDiscard: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.createdAt) private var tags: [Tag]

    @State private var date: Date
    @State private var minutes: Int
    @State private var memo: String
    @State private var selectedTag: Tag?
    @State private var newTagName = ""
    @State private var newTagColor = TagPalette.colors[0]
    @State private var errorMessage: String?

    init(mode: SessionFormMode,
         onSaved: @escaping (RecordOutcome?) -> Void = { _ in },
         onDiscard: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSaved = onSaved
        self.onDiscard = onDiscard
        switch mode {
        case .timer(let startedAt, let minutes):
            _date = State(initialValue: startedAt)
            _minutes = State(initialValue: minutes)
            _memo = State(initialValue: "")
            _selectedTag = State(initialValue: nil)
        case .manual:
            _date = State(initialValue: .now)
            _minutes = State(initialValue: 30)
            _memo = State(initialValue: "")
            _selectedTag = State(initialValue: nil)
        case .edit(let session):
            _date = State(initialValue: session.startedAt)
            _minutes = State(initialValue: session.minutes)
            _memo = State(initialValue: session.memo)
            _selectedTag = State(initialValue: session.tag)
        }
    }

    private var isTimer: Bool {
        if case .timer = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .timer: return "おつかれさま"
        case .manual: return "手入力"
        case .edit: return "記録を編集"
        }
    }

    private var isValid: Bool {
        (1...TimerMath.maxMinutes).contains(minutes)
    }

    private var sortedTags: [Tag] {
        tags.sorted { lastUsed($0) > lastUsed($1) }
    }

    private func lastUsed(_ tag: Tag) -> Date {
        tag.sessions.map(\.startedAt).max() ?? tag.createdAt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("時間") {
                    if !isTimer {
                        DatePicker("日付", selection: $date, in: ...Date.now, displayedComponents: .date)
                    }
                    HStack {
                        TextField("分", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                        Text("分")
                        Stepper("分数", value: $minutes, in: 1...TimerMath.maxMinutes, step: 5)
                            .labelsHidden()
                    }
                    if !isValid {
                        Text("1〜\(TimerMath.maxMinutes) 分で入力してください")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("タグ（任意）") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(sortedTags) { tag in
                                tagChip(tag)
                            }
                        }
                    }
                    HStack {
                        TextField("新しいタグ", text: $newTagName)
                        Button("追加", action: addTag)
                            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HStack {
                        ForEach(TagPalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if hex == newTagColor {
                                        Circle().stroke(Color.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { newTagColor = hex }
                        }
                    }
                }

                Section("メモ（任意）") {
                    TextField("やったこと", text: $memo, axis: .vertical)
                        .lineLimit(1...4)
                }

                if isTimer {
                    Section {
                        Button("この計測を破棄", role: .destructive) {
                            onDiscard()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isTimer ? "計測に戻る" : "キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!isValid)
                }
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
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = selectedTag?.id == tag.id
        return Text(tag.name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: tag.colorHex).opacity(isSelected ? 1 : 0.2), in: Capsule())
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .onTapGesture { selectedTag = isSelected ? nil : tag }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        if let existing = tags.first(where: { $0.name == name }) {
            selectedTag = existing
        } else {
            let tag = Tag(name: name, colorHex: newTagColor)
            context.insert(tag)
            selectedTag = tag
        }
        newTagName = ""
    }

    private func save() {
        do {
            let service = RecordService(context: context)
            switch mode {
            case .timer(let startedAt, _):
                onSaved(try service.save(startedAt: startedAt, minutes: minutes, tag: selectedTag,
                                         memo: memo, source: .timer))
            case .manual:
                onSaved(try service.save(startedAt: date, minutes: minutes, tag: selectedTag,
                                         memo: memo, source: .manual))
            case .edit(let session):
                session.startedAt = date
                session.minutes = minutes
                session.memo = memo
                session.tag = selectedTag
                try context.save()
                onSaved(nil)
            }
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました。もう一度お試しください。"
        }
    }
}

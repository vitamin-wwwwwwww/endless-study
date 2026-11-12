import SwiftUI
import SwiftData
import StudyCore

private struct FormRequest: Identifiable {
    let id = UUID()
    let mode: SessionFormMode
}

private struct OutcomeBox: Identifiable {
    let id = UUID()
    let outcome: RecordOutcome
}

struct HomeView: View {
    @Environment(TimerStore.self) private var timer
    @Query private var sessions: [StudySession]
    @Query private var states: [PlayerState]

    @State private var formRequest: FormRequest?
    @State private var pendingOutcome: RecordOutcome?
    @State private var shownOutcome: OutcomeBox?

    private var snapshot: ProgressSnapshot {
        StudyProgress.snapshot(sessions: sessions.map(\.record), bonusXP: states.first?.bonusXP ?? 0,
                          today: .now, calendar: .current)
    }

    private var equippedTitle: String? {
        states.first?.equippedTitleID.flatMap { RewardCatalog.reward(id: $0)?.name }
    }

    var body: some View {
        let snapshot = self.snapshot
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakCard(snapshot)
                    levelCard(snapshot)
                    todayCard(snapshot)
                    timerSection
                    Button {
                        formRequest = FormRequest(mode: .manual)
                    } label: {
                        Label("手入力で記録", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("Endless Study")
        }
        .sheet(item: $formRequest, onDismiss: showPendingOutcome) { request in
            SessionFormView(
                mode: request.mode,
                onSaved: { outcome in
                    if case .timer = request.mode { timer.clear() }
                    pendingOutcome = outcome
                },
                onDiscard: { timer.clear() }
            )
        }
        .sheet(item: $shownOutcome) { box in
            ResultView(outcome: box.outcome)
        }
    }

    private func showPendingOutcome() {
        if let outcome = pendingOutcome {
            pendingOutcome = nil
            shownOutcome = OutcomeBox(outcome: outcome)
        }
    }

    private func streakCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(snapshot.streak.current > 0 ? Color.orange : Color.secondary)
            Text("\(snapshot.streak.current) 日連続")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            Text("最長 \(snapshot.streak.longest) 日")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func levelCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lv \(snapshot.level.level)")
                    .font(.title2.bold())
                if let equippedTitle {
                    Text(equippedTitle)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(TintShapeStyle().opacity(0.2), in: Capsule())
                }
                Spacer()
                Text("\(snapshot.level.xpIntoLevel) / \(snapshot.level.xpForNextLevel) XP")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: snapshot.level.fraction)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func todayCard(_ snapshot: ProgressSnapshot) -> some View {
        HStack {
            Text("今日")
            Spacer()
            Text(formatMinutes(snapshot.todayMinutes))
                .font(.title3.bold())
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var timerSection: some View {
        if let startedAt = timer.startedAt {
            VStack(spacing: 12) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedText(from: startedAt, to: context.date))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                }
                Button {
                    let minutes = TimerMath.elapsedMinutes(from: startedAt, to: .now)
                    formRequest = FormRequest(mode: .timer(startedAt: startedAt, minutes: minutes))
                } label: {
                    Label("停止して記録", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            }
        } else {
            Button {
                timer.start()
            } label: {
                Label("タイマー開始", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func elapsedText(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}

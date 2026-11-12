import SwiftUI
import SwiftData

@main
struct EndlessStudyApp: App {
    @State private var timer = TimerStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timer)
                .environment(router)
        }
        .modelContainer(for: [StudySession.self, Tag.self, OwnedReward.self, PlayerState.self])
    }
}

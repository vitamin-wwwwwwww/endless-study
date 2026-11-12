import SwiftUI
import SwiftData
import Observation

enum AppTab: Hashable {
    case home, history, collection
}

@Observable
final class AppRouter {
    var tab: AppTab = .home
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Query private var states: [PlayerState]

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)
            HistoryView()
                .tabItem { Label("記録", systemImage: "calendar") }
                .tag(AppTab.history)
            CollectionView()
                .tabItem { Label("コレクション", systemImage: "sparkles") }
                .tag(AppTab.collection)
        }
        .tint(AppTheme.color(themeID: states.first?.equippedThemeID))
    }
}

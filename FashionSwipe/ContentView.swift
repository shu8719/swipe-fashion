import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SwipeView()
                .tabItem { Label("スワイプ", systemImage: "hand.draw") }

            RecommendationsView()
                .tabItem { Label("おすすめ", systemImage: "sparkles") }

            HistoryView()
                .tabItem { Label("履歴", systemImage: "heart.fill") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
    }
}

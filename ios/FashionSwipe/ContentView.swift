import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var navigation: AppNavigation

    var body: some View {
        // 4画面は消さずに重ね、表示するものだけ切り替える（スクロール位置などを保つため）
        ZStack {
            ForEach(AppTab.allCases) { tab in
                let isActive = navigation.selectedTab == tab
                screen(for: tab)
                    .environment(\.isTabActive, isActive)
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !navigation.isSelectingLikes {
                AppNavigationBar(selection: $navigation.selectedTab)
            }
        }
        .background(Theme.Colors.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .swipe:     SwipeView()
        case .recommend: RecommendationsView()
        case .likes:     HistoryView()
        case .myPage:    SettingsView()
        }
    }
}

private struct IsTabActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// その画面が今表示中のタブか（隠れている間に通信などを走らせないために使う）
    var isTabActive: Bool {
        get { self[IsTabActiveKey.self] }
        set { self[IsTabActiveKey.self] = newValue }
    }
}

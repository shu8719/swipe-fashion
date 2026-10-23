import SwiftUI
import Combine

/// 下部ナビゲーションのタブ
enum AppTab: CaseIterable, Identifiable {
    case swipe, recommend, likes, myPage

    var id: Self { self }

    var title: String {
        switch self {
        case .swipe:     return "スワイプ"
        case .recommend: return "おすすめ"
        case .likes:     return "LIKE"
        case .myPage:    return "マイページ"
        }
    }

    var icon: String {
        switch self {
        case .swipe:     return "hand.draw"
        case .recommend: return "sparkles"
        case .likes:     return "heart"
        case .myPage:    return "person.crop.circle"
        }
    }

    /// 選択中は塗りの版を使う
    var selectedIcon: String {
        switch self {
        case .recommend: return "sparkles"
        default:         return icon + ".fill"
        }
    }
}

/// タブの切り替えと、ナビゲーションバーの差し替え（LIKE の選択モード）を画面間で共有する
@MainActor
final class AppNavigation: ObservableObject {
    @Published var selectedTab: AppTab = .swipe
    /// true の間はナビゲーションバーを隠し、LIKE 画面が操作バーを出す
    @Published var isSelectingLikes = false
}

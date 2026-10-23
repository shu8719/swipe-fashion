#if DEBUG
import Foundation

/// Figma と見比べるスクリーンショット用に、起動オプションで画面と状態を直接開く（DEBUG ビルドのみ）。
///
///     xcrun simctl launch <device> FS.FashionSwipe -scenario swipe-like -seedLikes 17
enum ScreenshotScenario: String {
    case swipe              = "swipe"               // 01
    case swipeLike          = "swipe-like"          // 02 ドラッグ中（LIKE）
    case filter             = "filter"              // 03 絞り込みシート
    case recommend          = "recommend"           // 04 / 06（サーバーを止めると 06）
    case recommendFewLikes  = "recommend-few"       // 05 LIKE 3件未満
    case likes              = "likes"               // 07
    case likesSelecting     = "likes-select"        // 08 選択モード
    case myPage             = "mypage"              // 09
    case myPageDeleteAll    = "mypage-delete"       // 10 全削除の確認

    /// 起動オプション `-scenario <name>`（UserDefaults の引数ドメインに入る）
    static var current: ScreenshotScenario? {
        UserDefaults.standard.string(forKey: "scenario").flatMap(Self.init(rawValue:))
    }

    /// 起動オプション `-seedLikes <n>` で、LIKE をこの件数に置き換える
    static var seedLikes: Int? {
        UserDefaults.standard.object(forKey: "seedLikes") == nil
            ? nil
            : UserDefaults.standard.integer(forKey: "seedLikes")
    }

    var tab: AppTab {
        switch self {
        case .swipe, .swipeLike, .filter:        return .swipe
        case .recommend, .recommendFewLikes:     return .recommend
        case .likes, .likesSelecting:            return .likes
        case .myPage, .myPageDeleteAll:          return .myPage
        }
    }

    @MainActor
    static func apply(viewModel: SwipeViewModel, navigation: AppNavigation) {
        if let count = seedLikes {
            // 毎回同じ商品になるよう、ID 順に先頭から選ぶ
            let items = MockDataService.loadItems(for: .all).sorted { $0.id < $1.id }
            viewModel.debugReplaceLikes(with: Array(items.prefix(count)))
        }
        if let scenario = current {
            navigation.selectedTab = scenario.tab
        }
    }
}
#endif

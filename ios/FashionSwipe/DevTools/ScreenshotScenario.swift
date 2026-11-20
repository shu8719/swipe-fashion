#if DEBUG
import Foundation

/// Figma と見比べるスクリーンショット用に、起動オプションで画面と状態を直接開く（DEBUG ビルドのみ）。
///
///     xcrun simctl launch <device> FS.FashionSwipe -scenario swipe-like -seedLikes 17
///     xcrun simctl launch <device> FS.FashionSwipe -scenario recommend -seedLikes 17 -seedKeyword きれいめ
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
    case demo               = "demo"                // README の GIF（スワイプ → 取り消し → おすすめを自動で再生）

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
        case .swipe, .swipeLike, .filter, .demo: return .swipe
        case .recommend, .recommendFewLikes:     return .recommend
        case .likes, .likesSelecting:            return .likes
        case .myPage, .myPageDeleteAll:          return .myPage
        }
    }

    /// 起動オプション `-seedKeyword <語>` で、商品名にこの語を含む商品から LIKE を選ぶ
    /// （好みに一貫性のある LIKE にして、AI スタイル診断やおすすめの見え方を確かめるため）
    static var seedKeyword: String? {
        UserDefaults.standard.string(forKey: "seedKeyword").flatMap { $0.isEmpty ? nil : $0 }
    }

    @MainActor
    static func apply(viewModel: SwipeViewModel, navigation: AppNavigation) {
        if let count = seedLikes {
            // 毎回同じ商品になるよう ID 順に並べ、種別が偏らないよう種別ごとに1件ずつ順番に選ぶ
            let items = ProductCatalog.loadItems(for: .all)
                .filter { item in seedKeyword.map { item.itemName.contains($0) } ?? true }
                .sorted { $0.id < $1.id }
            let groups = Dictionary(grouping: items) { ProductCatalog.itemType(for: $0.id) }
                .sorted { ($0.key?.rawValue ?? "~") < ($1.key?.rawValue ?? "~") }
                .map(\.value)
            var picked: [Item] = []
            var index = 0
            while picked.count < count, groups.contains(where: { $0.count > index }) {
                for group in groups where group.count > index && picked.count < count {
                    picked.append(group[index])
                }
                index += 1
            }
            viewModel.debugReplaceLikes(with: picked)
        }
        if let scenario = current {
            navigation.selectedTab = scenario.tab
        }
    }
}
#endif

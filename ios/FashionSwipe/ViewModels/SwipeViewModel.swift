import Foundation
import Combine

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var cards: [Item] = []
    @Published private(set) var likedItems: [Item] = []
    @Published private(set) var profile: UserProfile = .default
    @Published private(set) var recommendedItems: [Item] = []
    /// 取り消せる直前のスワイプ（1件だけ）
    @Published private(set) var lastSwipe: SwipeRecord?

    struct SwipeRecord {
        enum Action { case like, skip }
        let item: Item
        let action: Action
        /// この LIKE で新しく LIKE 一覧に入ったか（取り消すときに外す）
        let addedToLikes: Bool
    }

    private let likedItemsKey  = "likedItems"
    private let userProfileKey = "userProfile"

    /// 重ねて表示するカード（前面と、その後ろに等倍で待機する1枚）
    var displayCards: [Item] { Array(cards.prefix(2)) }
    var canUndo: Bool { lastSwipe != nil }

    /// AI スタイル診断は LIKE 10件ごとに作り直される
    static let tasteInterval = 10
    var likesUntilNextTaste: Int { Self.tasteInterval - likedItems.count % Self.tasteInterval }
    var tasteProgress: Int { likedItems.count % Self.tasteInterval }

    init() {
        likedItems = loadLikedItems()
        profile    = loadProfile()
        cards      = loadFilteredCards()
        refreshRecommendations()
    }

    // MARK: - Swipe Actions

    func like() {
        guard let top = cards.first else { return }
        let isNew = !likedItems.contains(where: { $0.id == top.id })
        if isNew {
            likedItems.append(top)
            saveLikedItems()
            refreshRecommendations()
        }
        cards.removeFirst()
        lastSwipe = SwipeRecord(item: top, action: .like, addedToLikes: isNew)
        replenishIfNeeded()
        // バックエンドへ非同期送信（失敗しても UI はブロックしない）
        let code = top.itemCode
        Task { try? await ActionService.sendLike(itemCode: code) }
    }

    func dislike() {
        guard let top = cards.first else { return }
        cards.removeFirst()
        lastSwipe = SwipeRecord(item: top, action: .skip, addedToLikes: false)
        replenishIfNeeded()
        let code = top.itemCode
        Task { try? await ActionService.sendSkip(itemCode: code) }
    }

    /// 直前の1件だけ戻す。サーバーには取り消しの API がないため、端末側だけ戻す
    // TODO: サーバーに取り消し API ができたら、送信済みの LIKE / SKIP も取り消す
    func undoLastSwipe() {
        guard let record = lastSwipe else { return }
        lastSwipe = nil
        if record.addedToLikes {
            likedItems.removeAll { $0.id == record.item.id }
            saveLikedItems()
            refreshRecommendations()
        }
        cards.removeAll { $0.id == record.item.id }
        cards.insert(record.item, at: 0)
    }

    func unlike(item: Item) {
        guard likedItems.contains(where: { $0.id == item.id }) else { return }
        likedItems.removeAll { $0.id == item.id }
        saveLikedItems()
        refreshRecommendations()
    }

    func clearAllLikes() {
        guard !likedItems.isEmpty else { return }
        likedItems.removeAll()
        saveLikedItems()
        refreshRecommendations()
    }

    // MARK: - Profile / Filter

    func updateProfile(_ newProfile: UserProfile) {
        let changed = newProfile.category   != profile.category ||
                      newProfile.priceRange != profile.priceRange ||
                      newProfile.itemType   != profile.itemType
        profile = newProfile
        saveProfile()
        if changed { resetCards(); refreshRecommendations() }
    }

    func resetFilters() {
        var p = profile; p.category = .all; p.priceRange = .all; p.itemType = .all
        updateProfile(p)
    }

    #if DEBUG
    /// スクリーンショット用（DevTools/ScreenshotScenario）に LIKE を置き換える
    func debugReplaceLikes(with items: [Item]) {
        likedItems = items
        saveLikedItems()
        resetCards()
        refreshRecommendations()
    }
    #endif

    /// 絞り込みシートの「この条件で n件 を見る」の件数（スワイプに出る商品数＝LIKE 済みを除く）
    func matchingItemCount(for p: UserProfile) -> Int {
        let likedIds = Set(likedItems.map(\.id))
        return MockDataService.loadItems(for: p.category, type: p.itemType)
            .filter { p.priceRange.matches(price: $0.itemPrice) && !likedIds.contains($0.id) }
            .count
    }

    // MARK: - Recommendations

    func refreshRecommendations() {
        recommendedItems = computeRecommendations()
    }

    private func computeRecommendations() -> [Item] {
        let likedIds = Set(likedItems.map { $0.id })

        if likedItems.count >= 3 {
            let likedGenres = Set(likedItems.map { $0.genreId })
            let avgPrice    = max(likedItems.reduce(0) { $0 + $1.itemPrice } / likedItems.count, 1)

            let scored: [(Item, Double)] = MockDataService.loadItems(for: .all, type: profile.itemType)
                .filter { !likedIds.contains($0.id) }
                .map { item in
                    let genreScore = likedGenres.contains(item.genreId) ? 100.0 : 0.0
                    let priceScore = max(0.0, 100.0 - Double(abs(item.itemPrice - avgPrice)) / Double(avgPrice) * 100.0)
                    return (item, genreScore + priceScore * 0.5)
                }
            return scored.sorted { $0.1 > $1.1 }.prefix(20).map { $0.0 }
        } else {
            return MockDataService.loadItems(for: profile.category, type: profile.itemType)
                .filter { profile.priceRange.matches(price: $0.itemPrice) }
                .filter { !likedIds.contains($0.id) }
                .shuffled()
                .prefix(20)
                .map { $0 }
        }
    }

    // MARK: - Private Helpers

    private func resetCards() {
        cards = loadFilteredCards()
        lastSwipe = nil   // 条件が変わったら、前の条件のカードは戻さない
    }

    private func loadFilteredCards() -> [Item] {
        MockDataService.loadItems(for: profile.category, type: profile.itemType)
            .filter { profile.priceRange.matches(price: $0.itemPrice) }
            .filter { item in !likedItems.contains(where: { $0.id == item.id }) }
    }

    private func replenishIfNeeded() {
        guard cards.count < 5 else { return }
        let existing = Set(cards.map { $0.id })
        cards.append(contentsOf: loadFilteredCards().filter { !existing.contains($0.id) })
    }

    private func saveLikedItems() {
        guard let data = try? JSONEncoder().encode(likedItems) else { return }
        UserDefaults.standard.set(data, forKey: likedItemsKey)
    }

    private func loadLikedItems() -> [Item] {
        guard let data = UserDefaults.standard.data(forKey: likedItemsKey),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return items
    }

    private func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: userProfileKey)
    }

    private func loadProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: userProfileKey),
              let p = try? JSONDecoder().decode(UserProfile.self, from: data) else { return .default }
        return p
    }
}

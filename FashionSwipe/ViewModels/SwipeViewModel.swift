import Foundation
import Combine

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var cards: [Item] = []
    @Published private(set) var likedItems: [Item] = []
    @Published private(set) var profile: UserProfile = .default
    @Published private(set) var recommendedItems: [Item] = []

    private let likedItemsKey  = "likedItems"
    private let userProfileKey = "userProfile"

    var displayCards: [Item] { Array(cards.prefix(3)) }

    init() {
        likedItems = loadLikedItems()
        profile    = loadProfile()
        cards      = loadFilteredCards()
        refreshRecommendations()
    }

    // MARK: - Swipe Actions

    func like() {
        guard let top = cards.first else { return }
        if !likedItems.contains(where: { $0.id == top.id }) {
            likedItems.append(top)
            saveLikedItems()
            refreshRecommendations()
        }
        cards.removeFirst()
        replenishIfNeeded()
        // バックエンドへ非同期送信（失敗しても UI はブロックしない）
        let code = top.itemCode
        Task { try? await ActionService.sendLike(itemCode: code) }
    }

    func dislike() {
        guard let top = cards.first else { return }
        cards.removeFirst()
        replenishIfNeeded()
        let code = top.itemCode
        Task { try? await ActionService.sendSkip(itemCode: code) }
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

    private func resetCards() { cards = loadFilteredCards() }

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

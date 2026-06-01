import Foundation
import Combine

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var cards: [Item] = []
    @Published private(set) var likedItems: [Item] = []
    @Published private(set) var profile: UserProfile = .default
    @Published private(set) var recommendedItems: [Item] = []

    private let likedItemsKey = "likedItems"
    private let userProfileKey = "userProfile"

    var displayCards: [Item] { Array(cards.prefix(3)) }

    init() {
        likedItems = loadLikedItems()
        profile = loadProfile()
        cards = loadFilteredCards()
        refreshRecommendations()
    }

    func like() {
        guard let top = cards.first else { return }
        if !likedItems.contains(where: { $0.id == top.id }) {
            likedItems.append(top)
            saveLikedItems()
            refreshRecommendations()
        }
        cards.removeFirst()
        replenishIfNeeded()
    }

    func dislike() {
        guard !cards.isEmpty else { return }
        cards.removeFirst()
        replenishIfNeeded()
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

    func updateProfile(_ newProfile: UserProfile) {
        let categoryOrPriceChanged =
            newProfile.category != profile.category ||
            newProfile.priceRange != profile.priceRange
        profile = newProfile
        saveProfile()
        if categoryOrPriceChanged {
            resetCards()
            refreshRecommendations()
        }
    }

    func resetFilters() {
        var newProfile = profile
        newProfile.category = .all
        newProfile.priceRange = .all
        updateProfile(newProfile)
    }

    func refreshRecommendations() {
        // TODO: 将来 GET /api/recommend に置き換える。
        // 現状はローカルJSON + likedItems をもとにした仮実装。
        recommendedItems = computeRecommendations()
    }

    private func computeRecommendations() -> [Item] {
        let likedIds = Set(likedItems.map { $0.id })

        if likedItems.count >= 3 {
            // モードA: パーソナライズ（LIKE 3件以上）
            let likedGenres = Set(likedItems.map { $0.genreId })
            let totalPrice = likedItems.reduce(0) { $0 + $1.itemPrice }
            let avgPrice = totalPrice / likedItems.count
            let safeAvg = max(avgPrice, 1)

            let candidates = MockDataService.loadItems(for: .all)
                .filter { !likedIds.contains($0.id) }

            let scored: [(Item, Double)] = candidates.map { item in
                let genreScore = likedGenres.contains(item.genreId) ? 100.0 : 0.0
                let priceDiff = abs(item.itemPrice - avgPrice)
                let priceScore = max(0.0, 100.0 - Double(priceDiff) / Double(safeAvg) * 100.0)
                let total = genreScore + priceScore * 0.5
                return (item, total)
            }

            let topItems = scored.sorted { $0.1 > $1.1 }.prefix(20)
            return topItems.map { $0.0 }
        } else {
            // モードB: カテゴリベース（LIKE 2件以下）
            let filtered = MockDataService.loadItems(for: profile.category)
                .filter { profile.priceRange.matches(price: $0.itemPrice) }
                .filter { !likedIds.contains($0.id) }
            return Array(filtered.shuffled().prefix(20))
        }
    }

    private func resetCards() {
        cards = loadFilteredCards()
    }

    private func loadFilteredCards() -> [Item] {
        MockDataService.loadItems(for: profile.category)
            .filter { profile.priceRange.matches(price: $0.itemPrice) }
            .filter { item in !likedItems.contains(where: { $0.id == item.id }) }
    }

    private func saveLikedItems() {
        guard let data = try? JSONEncoder().encode(likedItems) else { return }
        UserDefaults.standard.set(data, forKey: likedItemsKey)
    }

    private func loadLikedItems() -> [Item] {
        guard let data = UserDefaults.standard.data(forKey: likedItemsKey),
              let items = try? JSONDecoder().decode([Item].self, from: data)
        else { return [] }
        return items
    }

    private func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: userProfileKey)
    }

    private func loadProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: userProfileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return .default }
        return profile
    }

    private func replenishIfNeeded() {
        if cards.count < 5 {
            let fresh = loadFilteredCards()
            let existingIds = Set(cards.map { $0.id })
            let toAppend = fresh.filter { !existingIds.contains($0.id) }
            cards.append(contentsOf: toAppend)
        }
    }
}

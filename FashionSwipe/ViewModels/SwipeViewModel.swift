import Foundation

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var cards: [APIItem] = []
    @Published private(set) var likedItems: [APIItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var displayCards: [APIItem] { Array(cards.prefix(3)) }

    func load() async {
        guard cards.isEmpty else { return }
        await fetchMore()
    }

    func like() {
        guard let top = cards.first else { return }
        likedItems.append(top)
        cards.removeFirst()
        let code = top.itemCode
        Task { try? await ActionService.sendLike(itemCode: code) }
        Task { await replenishIfNeeded() }
    }

    func dislike() {
        guard let top = cards.first else { return }
        cards.removeFirst()
        let code = top.itemCode
        Task { try? await ActionService.sendSkip(itemCode: code) }
        Task { await replenishIfNeeded() }
    }

    private func replenishIfNeeded() async {
        guard cards.count < 5 else { return }
        await fetchMore()
    }

    private func fetchMore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await ItemService.fetchNext(limit: 10)
            let likedCodes   = Set(likedItems.map(\.itemCode))
            let currentCodes = Set(cards.map(\.itemCode))
            let fresh = fetched.filter { !likedCodes.contains($0.itemCode) && !currentCodes.contains($0.itemCode) }
            cards.append(contentsOf: fresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import Foundation
import Combine

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published private(set) var cards: [Item] = []
    @Published private(set) var likedItems: [Item] = []

    var displayCards: [Item] { Array(cards.prefix(3)) }

    init() {
        cards = MockDataService.loadItems()
    }

    func like() {
        guard let top = cards.first else { return }
        likedItems.append(top)
        cards.removeFirst()
        replenishIfNeeded()
    }

    func dislike() {
        guard !cards.isEmpty else { return }
        cards.removeFirst()
        replenishIfNeeded()
    }

    private func replenishIfNeeded() {
        if cards.count < 5 {
            let fresh = MockDataService.loadItems().filter { item in
                !likedItems.contains(where: { $0.id == item.id })
            }
            cards.append(contentsOf: fresh)
        }
    }
}

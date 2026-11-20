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

    /// スワイプした商品を LIKE する。アニメーションの間に先頭が入れ替わることがあるので、
    /// 先頭ではなく、スワイプを始めたときのカードを受け取る
    func like(_ item: Item) {
        guard let index = cards.firstIndex(where: { $0.id == item.id }) else { return }
        let isNew = !likedItems.contains(where: { $0.id == item.id })
        if isNew {
            likedItems.append(item)
            saveLikedItems()
            refreshRecommendations()
        }
        cards.remove(at: index)
        lastSwipe = SwipeRecord(item: item, action: .like, addedToLikes: isNew)
        replenishIfNeeded()
        // バックエンドへ非同期送信（失敗しても UI はブロックしない）
        let code = item.itemCode
        Task { try? await ActionService.sendLike(itemCode: code) }
    }

    func dislike(_ item: Item) {
        guard let index = cards.firstIndex(where: { $0.id == item.id }) else { return }
        cards.remove(at: index)
        lastSwipe = SwipeRecord(item: item, action: .skip, addedToLikes: false)
        replenishIfNeeded()
        let code = item.itemCode
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

    /// LIKE 画面の選択モードで、選んだ商品をまとめて外す
    // TODO: サーバーに LIKE を外す API ができたら、サーバー側からも外す
    func unlike(itemIDs: Set<String>) {
        guard !itemIDs.isEmpty else { return }
        likedItems.removeAll { itemIDs.contains($0.id) }
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
        return ProductCatalog.loadItems(for: p.category, type: p.itemType)
            .filter { p.priceRange.matches(price: $0.itemPrice) && !likedIds.contains($0.id) }
            .count
    }

    // MARK: - Recommendations

    /// LIKE がこの件数に達すると、おすすめがあなた向けに切り替わる
    static let personalizeThreshold = 3
    var isPersonalized: Bool { likedItems.count >= Self.personalizeThreshold }

    /// おすすめの並べ方
    enum RecommendationSource {
        /// LIKE 3件未満: レビューの多い順
        case popular
        /// サーバーの推薦: スタイル・色・シルエット・素材・価格帯の22次元タグで、好みに近い順
        case server
        /// サーバーにつながらないとき: 端末内で、ジャンルが同じ＋価格が近い順
        case local
    }
    @Published private(set) var recommendationSource: RecommendationSource = .popular

    /// サーバーから取ったおすすめ（好みに近い順）。取れていないとき・失敗したときは空で、端末内の計算を使う
    private var serverRanking: [RecommendedItem] = []
    private var serverReasons: [String: [String]] = [:]

    /// おすすめ画面の種別チップ（この画面だけで効く。スワイプの絞り込みとは別）
    @Published var recommendationType: UserProfile.ItemType = .all {
        didSet { if oldValue != recommendationType { refreshRecommendations() } }
    }

    func refreshRecommendations() {
        // LIKE が3件を下回ったら、前の好みで取ったサーバーの並びは捨てる
        if !isPersonalized {
            serverRanking = []
            serverReasons = [:]
        }
        (recommendedItems, recommendationSource) = computeRecommendations()
    }

    /// サーバーの推薦を取り直して、おすすめを並べ直す。LIKE はこの前にサーバーへ送り直しておく
    func loadServerRecommendations() async {
        guard isPersonalized else { return }
        do {
            serverRanking = try await RecommendService.fetchRecommendations()
        } catch {
            // 画面を離れて取り消されただけなら、今の並びのままにする
            if Task.isCancelled { return }
            // つながらないときは端末内の計算に戻す（前に取った並びは、LIKE が変わっているかもしれないので使わない）
            serverRanking = []
        }
        serverReasons = Dictionary(serverRanking.map { ($0.item.id, $0.reasons) }, uniquingKeysWith: { a, _ in a })
        refreshRecommendations()
    }

    /// 一覧のカードに出すおすすめ理由。並べ方と同じ基準で出す
    func recommendationReason(for item: Item) -> String? {
        switch recommendationSource {
        case .popular:
            return nil
        case .server:
            // 2つ並べるとカードに収まらないときは、一番効いているタグだけにする
            let tags = (serverReasons[item.id] ?? []).prefix(2)
            let joined = tags.joined(separator: "・")
            if joined.isEmpty { return nil }
            return joined.count <= 10 ? joined : tags.first
        case .local:
            // ジャンルが一致したものは「同じジャンル」、それ以外は価格の近さで選ばれているので「近い価格帯」
            return likedGenreIds.contains(item.genreId) ? "同じジャンル" : "近い価格帯"
        }
    }

    private var likedGenreIds: Set<Int> { Set(likedItems.map(\.genreId)) }

    private func computeRecommendations() -> ([Item], RecommendationSource) {
        let likedIds = Set(likedItems.map { $0.id })

        if isPersonalized {
            let fromServer = serverRanking
                .map(\.item)
                .filter { !likedIds.contains($0.id) }
                .filter { recommendationType == .all || ProductCatalog.itemType(for: $0.id) == recommendationType }
                .prefix(20)
            if !fromServer.isEmpty {
                return (Array(fromServer), .server)
            }
            return (computeLocalRecommendations(excluding: likedIds), .local)
        } else {
            // LIKE が少ないうちは「いま人気のアイテム」としてレビューの多い順に並べる
            let popular = ProductCatalog.loadItems(for: profile.category, type: profile.itemType)
                .filter { profile.priceRange.matches(price: $0.itemPrice) }
                .filter { !likedIds.contains($0.id) }
                .sorted { ($0.reviewCount, $0.reviewAverage) > ($1.reviewCount, $1.reviewAverage) }
                .prefix(20)
            return (Array(popular), .popular)
        }
    }

    /// サーバーにつながらないときのおすすめ。LIKE した服とジャンルが同じ商品を優先し、平均価格に近い順に並べる
    private func computeLocalRecommendations(excluding likedIds: Set<String>) -> [Item] {
        let likedGenres = likedGenreIds
        let avgPrice    = max(likedItems.reduce(0) { $0 + $1.itemPrice } / likedItems.count, 1)

        let scored: [(Item, Double)] = ProductCatalog.loadItems(for: .all, type: recommendationType)
            .filter { !likedIds.contains($0.id) }
            .map { item in
                let genreScore = likedGenres.contains(item.genreId) ? 100.0 : 0.0
                let priceScore = max(0.0, 100.0 - Double(abs(item.itemPrice - avgPrice)) / Double(avgPrice) * 100.0)
                return (item, genreScore + priceScore * 0.5)
            }
        return scored.sorted { $0.1 > $1.1 }.prefix(20).map { $0.0 }
    }

    /// 一覧のハートから LIKE を付け外しする。押した直後に一覧が並び替わらないよう、
    /// おすすめの再計算は画面を開き直したときに行う
    func setLiked(_ item: Item, _ liked: Bool) {
        let isLiked = likedItems.contains(where: { $0.id == item.id })
        guard liked != isLiked else { return }
        let wasPersonalized = isPersonalized
        if liked {
            likedItems.append(item)
            // LIKE 済みはスワイプに出さない（loadFilteredCards と同じ扱い）
            cards.removeAll { $0.id == item.id }
            if lastSwipe?.item.id == item.id { lastSwipe = nil }
            replenishIfNeeded()
            let code = item.itemCode
            Task { try? await ActionService.sendLike(itemCode: code) }
        } else {
            // TODO: サーバーに LIKE を外す API ができたら、サーバー側からも外す
            likedItems.removeAll { $0.id == item.id }
        }
        saveLikedItems()
        // LIKE 3件をまたいで並べ方（人気順 ⇔ あなた向け）が変わるときだけ作り直し、
        // 見出しと一覧の中身がずれないようにする
        if isPersonalized != wasPersonalized { refreshRecommendations() }
    }

    func isLiked(_ item: Item) -> Bool {
        likedItems.contains(where: { $0.id == item.id })
    }

    // MARK: - Private Helpers

    private func resetCards() {
        cards = loadFilteredCards()
        lastSwipe = nil   // 条件が変わったら、前の条件のカードは戻さない
    }

    private func loadFilteredCards() -> [Item] {
        ProductCatalog.loadItems(for: profile.category, type: profile.itemType)
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

import Foundation

/// バックエンドAPIから返される商品モデル（楽天形式JSON準拠）。
/// Swift の JSONDecoder でそのままデコードできる。
struct APIItem: Identifiable, Codable {
    // 楽天 itemCode が id になる（String）
    let itemCode: String
    let itemName: String
    let catchcopy: String
    let itemPrice: Int
    let shopName: String
    let reviewAverage: Double
    let reviewCount: Int
    let itemUrl: String
    let mediumImageUrls: [ImageUrlWrapper]
    let genreId: Int
    var score: Double?

    var id: String { itemCode }

    struct ImageUrlWrapper: Codable {
        let imageUrl: String
    }

    // /api/recommend が返す score フィールドは optional
    enum CodingKeys: String, CodingKey {
        case itemCode, itemName, catchcopy, itemPrice, shopName
        case reviewAverage, reviewCount, itemUrl, mediumImageUrls, genreId, score
    }

    // MARK: - Computed Properties（CardView から利用）

    var largeImageUrl: URL? {
        guard let raw = mediumImageUrls.first?.imageUrl else { return nil }
        let enlarged = raw.replacingOccurrences(of: "_ex=128x128", with: "_ex=600x600")
        return URL(string: enlarged)
    }

    var cleanName: String {
        itemName
            .replacingOccurrences(of: "【[^】]*】", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    var productUrl: URL? { URL(string: itemUrl) }
}

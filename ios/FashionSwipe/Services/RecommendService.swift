import Foundation

/// サーバーの推薦（/api/recommend）で返ってくる1件。商品の項目に、類似度と理由のタグが付く
struct RecommendedItem: Decodable {
    let item: Item
    let score: Double
    /// 好みに効いているタグのうち、この商品も持っているもの（例: ["モノトーン", "オーバーサイズ"]）
    let reasons: [String]

    private enum CodingKeys: String, CodingKey { case score, reasons }

    init(from decoder: Decoder) throws {
        item = try Item(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score   = try c.decode(Double.self, forKey: .score)
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
    }
}

enum RecommendService {
    /// アプリに載せている商品（scope=app）から、好みに近い順に取る。
    /// 種別の絞り込みは端末側で行うので、表示する件数より多めに取る
    static func fetchRecommendations(limit: Int = 100) async throws -> [RecommendedItem] {
        try await APIClient.shared.get("/api/recommend?scope=app&limit=\(limit)")
    }
}

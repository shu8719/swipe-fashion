import Foundation

// 楽天形式のレスポンスをラップする型（/api/items/next は配列直返し）
enum ItemService {
    static func fetchNext(limit: Int = 10) async throws -> [APIItem] {
        try await APIClient.shared.get("/api/items/next?limit=\(limit)")
    }
}

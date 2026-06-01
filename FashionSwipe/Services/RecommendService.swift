import Foundation

struct TasteResponse: Decodable {
    let description: String?
    let updatedAt: String?
    enum CodingKeys: String, CodingKey {
        case description
        case updatedAt = "updated_at"
    }
}

enum RecommendService {
    static func fetchRecommendations() async throws -> [APIItem] {
        try await APIClient.shared.get("/api/recommend")
    }
    static func fetchFavorites() async throws -> [APIItem] {
        try await APIClient.shared.get("/api/favorites")
    }
    static func fetchTaste() async throws -> TasteResponse {
        try await APIClient.shared.get("/api/taste")
    }
}

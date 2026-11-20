import Foundation

struct TasteResponse: Decodable {
    let description: String?
    let updatedAt: String?
    enum CodingKeys: String, CodingKey {
        case description
        case updatedAt = "updated_at"
    }
}

/// AI スタイル診断の説明文（/api/taste）を取る
enum TasteService {
    static func fetchTaste() async throws -> TasteResponse {
        try await APIClient.shared.get("/api/taste")
    }
}

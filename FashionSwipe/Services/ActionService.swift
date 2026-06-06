import Foundation

enum ActionService {
    private struct ActionBody: Encodable {
        let item_code: String   // 楽天 itemCode (String)
        let action: String
    }
    private struct OKResponse: Decodable { let ok: Bool }

    static func sendLike(itemCode: String) async throws {
        let _: OKResponse = try await APIClient.shared.post(
            "/api/actions", body: ActionBody(item_code: itemCode, action: "LIKE")
        )
    }

    static func sendSkip(itemCode: String) async throws {
        let _: OKResponse = try await APIClient.shared.post(
            "/api/actions", body: ActionBody(item_code: itemCode, action: "SKIP")
        )
    }

    static func syncLikes(itemCodes: [String]) async {
        let unique = Array(Set(itemCodes))
        await withTaskGroup(of: Void.self) { group in
            for code in unique {
                group.addTask { try? await sendLike(itemCode: code) }
            }
        }
    }
}

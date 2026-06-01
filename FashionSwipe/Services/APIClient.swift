import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "URLが不正です"
        case .unauthorized:          return "認証が必要です。再ログインしてください"
        case .httpError(let c, let m): return m ?? "HTTPエラー: \(c)"
        case .decodingError(let e):  return "データ解析エラー: \(e.localizedDescription)"
        case .networkError(let e):   return "ネットワークエラー: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    // バックエンド Flask のポートは 5000
    let baseURL = "http://localhost:5000"
    private let session = URLSession.shared

    private var token: String? { UserDefaults.standard.string(forKey: "auth_token") }

    private init() {}

    func get<T: Decodable>(_ path: String) async throws -> T {
        let req = try makeRequest(method: "GET", path: path)
        return try await execute(req)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var req = try makeRequest(method: "POST", path: path)
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    private func makeRequest(method: String, path: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func execute<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError.networkError(error) }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw APIError.unauthorized }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.httpError(http.statusCode, String(data: data, encoding: .utf8))
            }
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decodingError(error) }
    }
}

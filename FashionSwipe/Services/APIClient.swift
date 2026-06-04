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

    let baseURL = APIClient.resolveBaseURL()
    private let session = URLSession.shared

    private var token: String? { UserDefaults.standard.string(forKey: "auth_token") }
    private let tokenKey = "auth_token"
    private let userIdKey = "auth_user_id"

    private init() {}

    private static func resolveBaseURL() -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !value.isEmpty,
           !value.contains("$(") {
            return value
        }

        #if targetEnvironment(simulator)
        return "http://127.0.0.1:5001"
        #else
        return "http://172.20.10.9:5001"
        #endif
    }

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

    private func execute<T: Decodable>(_ req: URLRequest, allowAuthRetry: Bool = true) async throws -> T {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError.networkError(error) }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                guard allowAuthRetry, try await refreshDeviceToken() else {
                    throw APIError.unauthorized
                }

                var retry = req
                if let token {
                    retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                return try await execute(retry, allowAuthRetry: false)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.httpError(http.statusCode, String(data: data, encoding: .utf8))
            }
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decodingError(error) }
    }

    private func refreshDeviceToken() async throws -> Bool {
        guard let url = URL(string: baseURL + "/api/auth/device") else { throw APIError.invalidURL }

        struct DeviceBody: Encodable { let device_id: String }
        struct AuthResponse: Decodable { let user_id: Int; let token: String }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(DeviceBody(device_id: UIDeviceID.get()))

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError.networkError(error) }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return false
        }

        let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
        UserDefaults.standard.set(auth.token, forKey: tokenKey)
        UserDefaults.standard.set(auth.user_id, forKey: userIdKey)
        return true
    }
}

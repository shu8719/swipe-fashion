import Foundation

enum AuthService {
    // デバイスUUID匿名認証（メイン。ログイン画面不要）
    struct DeviceBody: Encodable { let device_id: String }

    // 将来のemail認証用
    struct RegisterBody: Encodable { let email: String; let password: String }
    struct LoginBody: Encodable    { let email: String; let password: String }

    struct AuthResponse: Decodable { let user_id: Int; let token: String }

    static func loginWithDevice() async throws -> AuthResponse {
        let deviceId = UIDeviceID.get()
        return try await APIClient.shared.post("/api/auth/device", body: DeviceBody(device_id: deviceId))
    }

    static func register(email: String, password: String) async throws -> AuthResponse {
        try await APIClient.shared.post("/api/auth/register", body: RegisterBody(email: email, password: password))
    }

    static func login(email: String, password: String) async throws -> AuthResponse {
        try await APIClient.shared.post("/api/auth/login", body: LoginBody(email: email, password: password))
    }
}

/// デバイス固有 UUID を UserDefaults で永続化するユーティリティ。
enum UIDeviceID {
    static func get() -> String {
        let key = "app_device_uuid"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}

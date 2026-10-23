import Foundation

enum AuthService {
    // デバイスUUID匿名認証（メイン。ログイン画面不要）
    struct DeviceBody: Encodable { let device_id: String }

    struct AuthResponse: Decodable { let user_id: Int; let token: String }

    static func loginWithDevice() async throws -> AuthResponse {
        let deviceId = UIDeviceID.get()
        return try await APIClient.shared.post("/api/auth/device", body: DeviceBody(device_id: deviceId))
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

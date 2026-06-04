import Combine
import Foundation

final class AuthStore: ObservableObject {
    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var userId: Int?

    private let tokenKey = "auth_token"
    private let userIdKey = "auth_user_id"

    init() {
        let token = UserDefaults.standard.string(forKey: "auth_token")
        isLoggedIn = token != nil
        userId = UserDefaults.standard.object(forKey: "auth_user_id") as? Int
    }

    func save(token: String, userId: Int) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(userId, forKey: userIdKey)
        self.userId = userId
        isLoggedIn = true
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        userId = nil
        isLoggedIn = false
    }
}

import SwiftUI

@main
struct FashionSwipeApp: App {
    @StateObject private var viewModel  = SwipeViewModel()
    @StateObject private var authStore  = AuthStore()
    @StateObject private var navigation = AppNavigation()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(authStore)
                .environmentObject(navigation)
                .task { await loginIfNeeded() }
        }
    }

    private func loginIfNeeded() async {
        guard !authStore.isLoggedIn else { return }
        do {
            let res = try await AuthService.loginWithDevice()
            authStore.save(token: res.token, userId: res.user_id)
        } catch {
            // バックエンド未起動の場合はローカルのみで動作継続
            print("[Auth] デバイス認証スキップ: \(error.localizedDescription)")
        }
    }
}

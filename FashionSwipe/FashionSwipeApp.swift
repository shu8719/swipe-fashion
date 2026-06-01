import SwiftUI

@main
struct FashionSwipeApp: App {
    @StateObject private var viewModel = SwipeViewModel()
    @StateObject private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(authStore)
                .task { await login() }
        }
    }

    private func login() async {
        guard !authStore.isLoggedIn else { return }
        do {
            let res = try await AuthService.loginWithDevice()
            authStore.save(token: res.token, userId: res.user_id)
        } catch {
            print("デバイス認証エラー: \(error)")
        }
    }
}

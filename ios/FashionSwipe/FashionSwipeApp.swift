import SwiftUI

@main
struct FashionSwipeApp: App {
    @StateObject private var viewModel  = SwipeViewModel()
    @StateObject private var authStore  = AuthStore()
    @StateObject private var navigation = AppNavigation()
    @StateObject private var taste      = TasteStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(authStore)
                .environmentObject(navigation)
                .environmentObject(taste)
                .environmentObject(ConnectionStatus.shared)
                .onAppear {
                    #if DEBUG
                    ScreenshotScenario.apply(viewModel: viewModel, navigation: navigation)
                    #endif
                }
                .task { await loginIfNeeded() }
        }
    }

    private func loginIfNeeded() async {
        guard !authStore.isLoggedIn else {
            // ログイン済みだと起動時に通信が起きないので、接続状態だけ軽く確かめる
            await ConnectionStatus.shared.retry()
            return
        }
        do {
            let res = try await AuthService.loginWithDevice()
            authStore.save(token: res.token, userId: res.user_id)
        } catch {
            // バックエンド未起動の場合はローカルのみで動作継続
            print("[Auth] デバイス認証スキップ: \(error.localizedDescription)")
        }
    }
}

import Foundation
import Combine

/// AI 診断サーバーとの接続状態。APIClient がすべての通信の成否で更新する
@MainActor
final class ConnectionStatus: ObservableObject {
    static let shared = ConnectionStatus()

    enum State { case unknown, connected, disconnected }

    @Published private(set) var state: State = .unknown
    /// 最後に通信に成功した時刻（アプリを閉じても残す）
    @Published private(set) var lastSuccessAt: Date?
    @Published private(set) var isRetrying = false

    private let lastSuccessKey = "server_last_success_at"

    private init() {
        lastSuccessAt = UserDefaults.standard.object(forKey: lastSuccessKey) as? Date
    }

    func recordSuccess() {
        state = .connected
        let now = Date()
        lastSuccessAt = now
        UserDefaults.standard.set(now, forKey: lastSuccessKey)
    }

    func recordFailure() {
        state = .disconnected
    }

    /// 既存の軽い GET（/health）でつながるか確かめる。結果は state に反映される
    func retry() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        try? await APIClient.shared.checkHealth()
    }
}

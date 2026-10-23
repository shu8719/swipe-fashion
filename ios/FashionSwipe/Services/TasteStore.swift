import Foundation
import Combine

/// AI スタイル診断（/api/taste）の説明文と、受け取った回数。おすすめ画面とマイページで共有する
@MainActor
final class TasteStore: ObservableObject {
    @Published private(set) var text: String?
    @Published private(set) var isFetching = false
    /// 新しい説明文を受け取った回数（サーバーが回数を返さないので端末側で数える）
    @Published private(set) var diagnosisCount: Int

    private let lastTextKey = "taste_last_text"
    private let countKey    = "taste_diagnosis_count"

    init() {
        diagnosisCount = UserDefaults.standard.integer(forKey: countKey)
    }

    /// 手元の LIKE をサーバーへ送り直し、届き終わってから説明文を取りに行く
    /// （先に取ると、サーバー側の LIKE が10件に届く前で空が返る）。
    /// syncLikes は並列・タイムアウト5秒なので、サーバー停止時も数秒で抜ける
    func load(likedItemCodes: [String]) async {
        guard likedItemCodes.count >= SwipeViewModel.tasteInterval else {
            text = nil
            return
        }
        await ActionService.syncLikes(itemCodes: likedItemCodes)
        guard !Task.isCancelled else { return }

        // 取得は1回だけ試みる（失敗しても読み込み中の表示を出し続けない）
        isFetching = true
        defer { isFetching = false }
        do {
            let resp = try await RecommendService.fetchTaste()
            guard let desc = resp.description, !desc.isEmpty else { return }
            if desc != UserDefaults.standard.string(forKey: lastTextKey) {
                diagnosisCount += 1
                UserDefaults.standard.set(diagnosisCount, forKey: countKey)
                UserDefaults.standard.set(desc, forKey: lastTextKey)
            }
            text = desc
        } catch {
            print("[Taste] fetch skipped: \(error.localizedDescription)")
        }
    }

    /// LIKE をすべて削除したときなど、表示中の説明文を消す
    func clear() {
        text = nil
    }
}

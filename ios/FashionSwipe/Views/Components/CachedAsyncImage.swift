import SwiftUI
import UIKit

/// URLをキーにデコード済み画像をメモリ保持する軽量キャッシュ。
/// NSCache はメモリ逼迫時に自動でエビクションするため、明示的な解放は不要。
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200   // 保持する画像枚数の上限（必要に応じて調整）
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// `AsyncImage` のドロップイン代替。
/// 標準の `AsyncImagePhase` をそのまま使うため、既存の `switch phase` クロージャを
/// 変更せずに `AsyncImage` → `CachedAsyncImage` の置き換えだけで利用できる。
///
/// - メモリキャッシュ（`ImageCache`）にヒットすれば再ダウンロード・再デコードを行わない。
/// - `URLSession.shared` 経由なので `URLCache.shared` のディスクキャッシュも併用される。
struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }

        // メモリキャッシュ命中 → 即座に表示（再取得しない）
        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        phase = .empty
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data, scale: scale) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }
            ImageCache.shared.insert(uiImage, for: url)
            // 取得中に url が差し替わっていなければ反映（セル再利用対策）
            if !Task.isCancelled {
                phase = .success(Image(uiImage: uiImage))
            }
        } catch {
            if !Task.isCancelled {
                phase = .failure(error)
            }
        }
    }
}

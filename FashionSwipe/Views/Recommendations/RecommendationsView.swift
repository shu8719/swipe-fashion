import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @State private var selectedItem: Item?
    @State private var tasteText: String?       = nil
    @State private var isTasteLoading: Bool     = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recommendedItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // ── AI スタイル診断カード ──────────────────
                            tasteCard
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // ── おすすめヘッダー ───────────────────────
                            header
                                .padding(.horizontal, 16)

                            // ── 商品グリッド ───────────────────────────
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(viewModel.recommendedItems) { item in
                                    ItemGridCell(item: item)
                                        .onTapGesture { selectedItem = item }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .navigationTitle("おすすめ")
            .task { await loadTaste() }
            .fullScreenCover(item: $selectedItem) { item in
                if let url = item.productUrl {
                    SafariView(url: url).ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - AI スタイル診断カード

    @ViewBuilder
    private var tasteCard: some View {
        let likeCount = viewModel.likedItems.count

        if isTasteLoading {
            // 読み込み中
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.8)
                Text("AIがあなたのスタイルを分析中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        } else if let text = tasteText {
            // 診断結果あり
            VStack(alignment: .leading, spacing: 6) {
                Label("あなたのスタイル診断", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )

        } else if likeCount > 0 && likeCount < 10 {
            // LIKE数不足
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink.opacity(0.6))
                    .font(.caption)
                Text("あと\(10 - likeCount)件LIKEするとAIスタイル診断が始まります")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        // likeCount == 0 の場合はカード非表示
    }

    // MARK: - Helpers

    private func loadTaste() async {
        guard viewModel.likedItems.count >= 10 else { return }
        isTasteLoading = true
        defer { isTasteLoading = false }
        do {
            let resp = try await RecommendService.fetchTaste()
            if let desc = resp.description, !desc.isEmpty {
                tasteText = desc
            }
        } catch {
            // バックエンド未起動などはサイレントに無視（ローカル動作継続）
            print("[Taste] fetch skipped: \(error.localizedDescription)")
        }
    }

    private var header: some View {
        Text(headerMessage)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerMessage: String {
        let count = viewModel.likedItems.count
        if count >= 3 {
            return "あなたのLIKE \(count)件 をもとにおすすめしています"
        } else if count > 0 {
            return "あと\(3 - count)件LIKEするとパーソナライズされます"
        } else {
            return "スワイプ画面でLIKEするとパーソナライズされます"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.4))
            Text("おすすめを準備できませんでした")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("スワイプを続けるとここに表示されます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

struct RecommendationsView: View {
    @State private var items: [APIItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: APIItem?
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("おすすめを取得中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(items) { item in
                                ItemGridCell(item: item).onTapGesture { selectedItem = item }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("おすすめ")
            .task { await load() }
            .fullScreenCover(item: $selectedItem) { item in
                if let url = item.productUrl { SafariView(url: url).ignoresSafeArea() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles").font(.system(size: 60)).foregroundColor(.purple.opacity(0.4))
            Text("Likeした商品が増えると\nおすすめが表示されます")
                .font(.headline).foregroundColor(.secondary).multilineTextAlignment(.center)
            if let e = errorMessage {
                Text(e).font(.caption).foregroundColor(.red).padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        do { items = try await RecommendService.fetchRecommendations() }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

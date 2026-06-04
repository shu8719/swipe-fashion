import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @State private var selectedItem: Item?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recommendedItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            header
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
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
            .fullScreenCover(item: $selectedItem) { item in
                if let url = item.productUrl {
                    SafariView(url: url).ignoresSafeArea()
                }
            }
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

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @State private var selectedItem: Item?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.likedItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.likedItems.reversed()) { item in
                                ItemGridCell(item: item)
                                    .onTapGesture { selectedItem = item }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Like済み (\(viewModel.likedItems.count)件)")
            .fullScreenCover(item: $selectedItem) { item in
                if let url = item.productUrl {
                    SafariView(url: url).ignoresSafeArea()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            Text("まだLikeした商品がありません")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ItemGridCell

struct ItemGridCell: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: item.largeImageUrl) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color.gray.opacity(0.15)
                        .overlay(ProgressView())
                }
            }
            .frame(height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.cleanName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            Text("¥\(item.itemPrice.formatted())")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

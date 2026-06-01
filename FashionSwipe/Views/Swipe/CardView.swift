import SwiftUI

struct CardView: View {
    let item: APIItem        // Item → APIItem に変更
    let offset: CGSize
    let likeOpacity: Double
    let nopeOpacity: Double

    @State private var showingSafari = false

    var body: some View {
        ZStack(alignment: .top) {
            cardContent
            overlayLabels
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .offset(x: offset.width, y: offset.height * 0.3)
        .rotationEffect(.degrees(Double(offset.width) * 0.05))
        .onTapGesture { if item.productUrl != nil { showingSafari = true } }
        .fullScreenCover(isPresented: $showingSafari) {
            if let url = item.productUrl {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            AsyncImage(url: item.largeImageUrl) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Color.gray.opacity(0.2)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                default: Color.gray.opacity(0.1).overlay(ProgressView())
                }
            }
            .frame(height: 400)
            .clipped()
            itemInfo
        }
        .background(Color.white)
    }

    private var itemInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.cleanName)
                .font(.subheadline).fontWeight(.medium).lineLimit(2)
            HStack(alignment: .bottom) {
                Text("¥\(item.itemPrice.formatted())")
                    .font(.title3).fontWeight(.bold)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").foregroundColor(.orange)
                    Text(String(format: "%.1f", item.reviewAverage))
                    Text("(\(item.reviewCount)件)").foregroundColor(.secondary)
                }
                .font(.caption)
            }
            HStack {
                Text(item.shopName)
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
                Spacer()
                Image(systemName: "safari").font(.caption).foregroundColor(.blue.opacity(0.6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overlayLabels: some View {
        HStack {
            SwipeLabelView(text: "LIKE", color: .green).opacity(likeOpacity)
            Spacer()
            SwipeLabelView(text: "NOPE", color: .red).opacity(nopeOpacity)
        }
        .padding(20)
    }
}

struct SwipeLabelView: View {
    let text: String; let color: Color
    var body: some View {
        Text(text).font(.title2).fontWeight(.heavy).foregroundColor(color)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(text == "LIKE" ? -15 : 15))
    }
}

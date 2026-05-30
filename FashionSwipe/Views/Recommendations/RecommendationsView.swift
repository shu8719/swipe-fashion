import SwiftUI

struct RecommendationsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.purple.opacity(0.4))
                Text("Likeした商品が増えると\nおすすめが表示されます")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("おすすめ")
        }
    }
}

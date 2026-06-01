import SwiftUI

struct SwipeView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @State private var offset: CGSize = .zero
    private let threshold: CGFloat = 120

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                cardStack
                actionButtons
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Fashion Swipe")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
        }
    }

    private var cardStack: some View {
        ZStack {
            if viewModel.cards.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.displayCards.dropFirst().reversed()) { item in
                    CardView(item: item, offset: .zero, likeOpacity: 0, nopeOpacity: 0)
                        .scaleEffect(scale(for: item))
                        .offset(y: yOffset(for: item))
                }
                if let top = viewModel.displayCards.first {
                    CardView(item: top, offset: offset, likeOpacity: likeOpacity, nopeOpacity: nopeOpacity)
                        .gesture(dragGesture)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: offset)
                }
            }
        }
        .frame(maxWidth: .infinity).frame(height: 560)
    }

    private var actionButtons: some View {
        HStack(spacing: 48) {
            CircleButton(icon: "xmark", color: .red)    { triggerSwipe(.dislike) }
            CircleButton(icon: "heart.fill", color: .green) { triggerSwipe(.like) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView().scaleEffect(1.5)
                Text("読み込み中...").foregroundColor(.secondary)
            } else {
                Image(systemName: "tshirt").font(.system(size: 60)).foregroundColor(.gray.opacity(0.4))
                Text("商品がありません").font(.headline).foregroundColor(.secondary)
            }
        }
    }

    private var likeOpacity:  Double { max(0, min(Double(offset.width) /  Double(threshold), 1.0)) }
    private var nopeOpacity:  Double { max(0, min(Double(-offset.width) / Double(threshold), 1.0)) }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { offset = $0.translation }
            .onEnded { v in
                if      v.translation.width >  threshold { performFlyOut(direction: .like) }
                else if v.translation.width < -threshold { performFlyOut(direction: .dislike) }
                else { withAnimation(.spring()) { offset = .zero } }
            }
    }

    private func triggerSwipe(_ dir: SwipeDirection) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        performFlyOut(direction: dir)
    }

    private func performFlyOut(direction: SwipeDirection) {
        let x: CGFloat = direction == .like ? 700 : -700
        withAnimation(.easeOut(duration: 0.28)) { offset = CGSize(width: x, height: offset.height) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            self.offset = .zero
            switch direction {
            case .like:    self.viewModel.like()
            case .dislike: self.viewModel.dislike()
            }
        }
    }

    private func scale(for item: APIItem) -> CGFloat {
        let i = viewModel.displayCards.firstIndex(where: { $0.id == item.id }) ?? 0
        return 1.0 - CGFloat(i) * 0.03
    }
    private func yOffset(for item: APIItem) -> CGFloat {
        let i = viewModel.displayCards.firstIndex(where: { $0.id == item.id }) ?? 0
        return CGFloat(i) * 10
    }

    enum SwipeDirection { case like, dislike }
}

struct CircleButton: View {
    let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2).fontWeight(.bold).foregroundColor(color)
                .frame(width: 64, height: 64)
                .background(color.opacity(0.12)).clipShape(Circle())
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
        }
    }
}

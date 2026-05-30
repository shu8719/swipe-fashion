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
        }
    }

    // MARK: - Card Stack

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
                    CardView(
                        item: top,
                        offset: offset,
                        likeOpacity: likeOpacity,
                        nopeOpacity: nopeOpacity
                    )
                    .gesture(dragGesture)
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: offset)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 560)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 48) {
            CircleButton(icon: "xmark", color: .red) {
                triggerSwipe(.dislike)
            }
            CircleButton(icon: "heart.fill", color: .green) {
                triggerSwipe(.like)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            Text("読み込み中...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Swipe Logic

    private var likeOpacity: Double {
        max(0, min(Double(offset.width) / Double(threshold), 1.0))
    }

    private var nopeOpacity: Double {
        max(0, min(Double(-offset.width) / Double(threshold), 1.0))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                if value.translation.width > threshold {
                    performFlyOut(direction: .like)
                } else if value.translation.width < -threshold {
                    performFlyOut(direction: .dislike)
                } else {
                    withAnimation(.spring()) { offset = .zero }
                }
            }
    }

    private func triggerSwipe(_ direction: SwipeDirection) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        performFlyOut(direction: direction)
    }

    private func performFlyOut(direction: SwipeDirection) {
        let targetX: CGFloat = direction == .like ? 700 : -700
        withAnimation(.easeOut(duration: 0.28)) {
            offset = CGSize(width: targetX, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            offset = .zero
            switch direction {
            case .like:    viewModel.like()
            case .dislike: viewModel.dislike()
            }
        }
    }

    // MARK: - Helpers

    private func scale(for item: Item) -> CGFloat {
        let index = viewModel.displayCards.firstIndex(where: { $0.id == item.id }) ?? 0
        return 1.0 - CGFloat(index) * 0.03
    }

    private func yOffset(for item: Item) -> CGFloat {
        let index = viewModel.displayCards.firstIndex(where: { $0.id == item.id }) ?? 0
        return CGFloat(index) * 10
    }

    enum SwipeDirection { case like, dislike }
}

// MARK: - CircleButton

struct CircleButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 64, height: 64)
                .background(color.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
        }
    }
}

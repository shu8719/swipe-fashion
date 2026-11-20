import SwiftUI

/// スワイプ画面（Figma: 01 スワイプ 4:19 / 02 スワイプ中 4:103）
struct SwipeView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @State private var offset: CGSize = .zero
    @State private var isFlyingOut = false
    @State private var showsFilter = false
    @State private var productToOpen: Item?
    #if DEBUG
    @EnvironmentObject private var navigation: AppNavigation
    #endif

    private let threshold: CGFloat = 120
    /// カードの画像より下（ショップ名〜価格の行）の高さ
    private let cardContentHeight: CGFloat = 152

    /// ドラッグの進み具合。プラスは LIKE、マイナスは SKIP（-1...1）
    private var dragProgress: CGFloat { max(-1, min(offset.width / threshold, 1)) }
    private var emphasizesLike: Bool { dragProgress > 0.3 }
    private var emphasizesSkip: Bool { dragProgress < -0.3 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            currentFilters
            diagnosisProgress
            cardStack
            actionButtons
        }
        .background(Theme.Colors.surface)
        .sheet(isPresented: $showsFilter) { FilterSheet() }
        .onAppear {
            #if DEBUG
            switch ScreenshotScenario.current {
            case .swipeLike: offset = CGSize(width: threshold, height: 0)
            case .filter:    showsFilter = true
            default:         break
            }
            #endif
        }
        .fullScreenCover(item: $productToOpen) { item in
            if let url = item.productUrl {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        #if DEBUG
        .task {
            if ScreenshotScenario.current == .demo { await playDemo() }
        }
        #endif
    }

    #if DEBUG
    /// README の GIF 用。ドラッグで LIKE → ドラッグで SKIP → 取り消し → LIKE → おすすめ画面、の順に自動で見せる。
    /// カードは指でドラッグしたときと同じ offset を動かし、飛ばすところはボタンやドラッグと同じ performFlyOut を使う
    private func playDemo() async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        func dragAndRelease(_ direction: SwipeDirection) async {
            let x: CGFloat = direction == .like ? threshold + 30 : -(threshold + 30)
            withAnimation(.easeInOut(duration: 0.7)) { offset = CGSize(width: x, height: 6) }
            await wait(0.9)
            performFlyOut(direction: direction)
            await wait(1.0)
        }

        // 何の商品か分かりやすいよう、服（トップス・ボトムス・ワンピース）だけを、毎回同じ順で出す。福袋は外す
        let clothes = ProductCatalog.loadItems(for: .all)
            .filter { item in
                guard let type = ProductCatalog.itemType(for: item.id) else { return false }
                return [.tops, .bottoms, .onepiece].contains(type)
            }
            .filter { !$0.itemName.contains("福袋") && !$0.itemName.localizedCaseInsensitiveContains("happy bag") }
            .filter { !viewModel.isLiked($0) }
            .filter { item in ScreenshotScenario.seedKeyword.map { item.itemName.contains($0) } ?? true }
            .sorted { $0.id < $1.id }
        viewModel.debugSetCards(Array(clothes.prefix(6)))

        await wait(2.0)
        await dragAndRelease(.like)
        await dragAndRelease(.skip)
        viewModel.undoLastSwipe()
        await wait(1.2)
        await dragAndRelease(.like)
        navigation.selectedTab = .recommend
        await wait(4.0)
        viewModel.recommendationType = .tops
        await wait(3.0)
        viewModel.recommendationType = .all
        await wait(1.5)
    }
    #endif

    // MARK: - Top app bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 48, height: 48)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.s8) {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Colors.brandGradient)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "tshirt")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                Text("Swipe Fashion")
                    .typography(Theme.Typography.logo)
                    .foregroundStyle(Theme.Colors.onSurface)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                showsFilter = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("絞り込み")
        }
        .padding(Theme.Spacing.s4)
    }

    // MARK: - Current filters（タップで絞り込みシート）

    private var currentFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s8) {
                AssistChip(icon: "person", label: categoryLabel) { showsFilter = true }
                AssistChip(icon: "tshirt", label: itemTypeLabel) { showsFilter = true }
                AssistChip(icon: "tag", label: priceLabel) { showsFilter = true }
            }
            .padding(.horizontal, Theme.Spacing.s16)
        }
        .padding(.bottom, Theme.Spacing.s8)
    }

    private var categoryLabel: String {
        viewModel.profile.category == .all ? "全カテゴリ" : viewModel.profile.category.displayName
    }
    private var itemTypeLabel: String {
        viewModel.profile.itemType == .all ? "全アイテム" : viewModel.profile.itemType.displayName
    }
    private var priceLabel: String {
        viewModel.profile.priceRange == .all ? "全価格帯" : viewModel.profile.priceRange.displayName
    }

    // MARK: - AI 診断までの進捗

    private var diagnosisProgress: some View {
        let remaining = viewModel.likesUntilNextTaste
        let label = viewModel.likedItems.count < SwipeViewModel.tasteInterval
            ? "あと\(remaining)件のLIKEで AIスタイル診断"
            : "あと\(remaining)件のLIKEで AIスタイル診断を更新"
        let fraction = CGFloat(viewModel.tasteProgress) / CGFloat(SwipeViewModel.tasteInterval)

        return VStack(spacing: Theme.Spacing.s8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                    Text(label)
                        .typography(Theme.Typography.labelMedium)
                        .foregroundStyle(Theme.Colors.onSurfaceVariant)
                }
                Spacer()
                Text("\(viewModel.tasteProgress) / \(SwipeViewModel.tasteInterval)")
                    .typography(Theme.Typography.labelMedium)
                    .foregroundStyle(Theme.Colors.primary)
            }
            Capsule()
                .fill(Theme.Colors.secondaryContainer)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.Colors.primary)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: fraction)
        }
        .padding(.horizontal, Theme.Spacing.s16)
        .padding(.top, Theme.Spacing.s4)
        .padding(.bottom, Theme.Spacing.s8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Card stack

    private var cardStack: some View {
        GeometryReader { geo in
            // 横は左右36pt空け、縦はボタンの上に収まるようにカードの幅を決める
            let width = max(200, min(geo.size.width - 72, geo.size.height - cardContentHeight - 18))

            ZStack(alignment: .top) {
                if viewModel.cards.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 2枚を1つの ForEach で描画し、商品IDを安定IDにする。
                    // 後ろのカードは等倍のまま実際の商品を出しておき、ドラッグ中に次の商品が見えるようにする。
                    // 前面が飛んだあと、後ろのカードが y=10 → 0 へなめらかに出てくる
                    ForEach(Array(viewModel.displayCards.enumerated()).reversed(), id: \.element.id) { index, item in
                        let isTop = index == 0
                        SwipeCard(item: item, dragProgress: isTop ? dragProgress : 0) {
                            productToOpen = item
                        }
                        .frame(width: width)
                        .offset(x: isTop ? offset.width : 0,
                                y: isTop ? offset.height * 0.3 : 10)
                        .rotationEffect(.degrees(isTop ? Double(dragProgress) * 8 : 0))
                        .zIndex(Double(viewModel.displayCards.count - index))
                        .onTapGesture { productToOpen = item }
                        .gesture(dragGesture)
                        .allowsHitTesting(isTop)
                        .accessibilityElement(children: .combine)
                        .accessibilityHidden(!isTop)
                        .accessibilityAction(named: "LIKE") { triggerSwipe(.like) }
                        .accessibilityAction(named: "SKIP") { triggerSwipe(.skip) }
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: offset)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.s4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.s16) {
            Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle" : "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.outline)

            Text(hasActiveFilter ? "条件に合う商品がありません" : "現在表示できる商品がありません")
                .typography(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            if hasActiveFilter {
                VStack(spacing: Theme.Spacing.s4) {
                    Text("現在の表示カテゴリ：\(viewModel.profile.category.displayName)")
                    Text("現在のアイテム種別：\(viewModel.profile.itemType.displayName)")
                    Text("現在の価格帯：\(viewModel.profile.priceRange.displayName)")
                }
                .typography(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)

                Button {
                    viewModel.resetFilters()
                } label: {
                    Text("条件をリセット")
                        .typography(Theme.Typography.labelLarge)
                        .foregroundStyle(Theme.Colors.onPrimary)
                        .padding(.horizontal, Theme.Spacing.s24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.Colors.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s8)
            }
        }
        .padding(.horizontal, Theme.Spacing.s24)
    }

    private var hasActiveFilter: Bool {
        viewModel.profile.category != .all ||
        viewModel.profile.priceRange != .all ||
        viewModel.profile.itemType != .all
    }

    // MARK: - Actions（SKIP / 取り消し / LIKE）

    private var actionButtons: some View {
        let isEmpty = viewModel.cards.isEmpty
        return HStack(spacing: Theme.Spacing.s12) {
            swipeButton(.skip)
                .opacity(emphasizesLike ? 0.5 : 1)
                .disabled(isEmpty)
            undoButton
                .opacity(emphasizesLike || emphasizesSkip ? 0.5 : 1)
            swipeButton(.like)
                .opacity(emphasizesSkip ? 0.5 : 1)
                .disabled(isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.s16)
        .padding(.top, Theme.Spacing.s8)
        .padding(.bottom, Theme.Spacing.s12)
        .animation(.easeOut(duration: 0.15), value: emphasizesLike)
        .animation(.easeOut(duration: 0.15), value: emphasizesSkip)
    }

    private func swipeButton(_ direction: SwipeDirection) -> some View {
        let isLike = direction == .like
        let emphasized = isLike ? emphasizesLike : emphasizesSkip
        let background: Color = isLike
            ? (emphasized ? Theme.Colors.like : Theme.Colors.likeContainer)
            : (emphasized ? Theme.Colors.skip : Theme.Colors.surfaceContainerHigh)
        let iconColor: Color = isLike
            ? (emphasized ? Theme.Colors.onTertiary : Theme.Colors.onLikeContainer)
            : (emphasized ? Theme.Colors.onError : Theme.Colors.skip)
        let textColor: Color = isLike
            ? (emphasized ? Theme.Colors.onTertiary : Theme.Colors.onLikeContainer)
            : (emphasized ? Theme.Colors.onError : Theme.Colors.onSurface)

        return Button {
            triggerSwipe(direction)
        } label: {
            HStack(spacing: Theme.Spacing.s8) {
                Image(systemName: isLike ? "heart.fill" : "xmark")
                    .font(.system(size: isLike ? 22 : 20, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(height: 28)
                Text(isLike ? "LIKE" : "SKIP")
                    .typography(Theme.Typography.titleMedium)
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.large).fill(background))
            .elevation(emphasized ? .level3 : .level1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        }
        .buttonStyle(.plain)
    }

    private var undoButton: some View {
        Button {
            viewModel.undoLastSwipe()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.Colors.surfaceContainerHigh))
                .elevation(.level1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // 飛んでいく間に戻すと、飛んだカードとは別のカードが評価されてしまうので押せなくする
        .disabled(!viewModel.canUndo || isFlyingOut)
        .opacity(viewModel.canUndo ? 1 : 0.38)
        .accessibilityLabel("取り消し")
    }

    // MARK: - Swipe Logic

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isFlyingOut else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isFlyingOut else { return }
                if value.translation.width > threshold {
                    performFlyOut(direction: .like)
                } else if value.translation.width < -threshold {
                    performFlyOut(direction: .skip)
                } else {
                    withAnimation(.spring()) { offset = .zero }
                }
            }
    }

    private func triggerSwipe(_ direction: SwipeDirection) {
        guard !isFlyingOut, !viewModel.cards.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        performFlyOut(direction: direction)
    }

    private func performFlyOut(direction: SwipeDirection) {
        // 飛んでいく間は次の操作を受け付けない（連打で見ていないカードまで評価しないため）
        // 評価するカードは飛ばし始めた時点で決めておく
        guard !isFlyingOut, let swiped = viewModel.cards.first else { return }
        isFlyingOut = true
        let targetX: CGFloat = direction == .like ? 700 : -700
        withAnimation(.easeOut(duration: 0.28)) {
            offset = CGSize(width: targetX, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            switch direction {
            case .like: viewModel.like(swiped)
            case .skip: viewModel.dislike(swiped)
            }
            offset = .zero
            isFlyingOut = false
        }
    }

    enum SwipeDirection { case like, skip }
}

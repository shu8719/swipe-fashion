import SwiftUI

/// おすすめ画面（Figma: 04 おすすめ 4:175 / 05 LIKE 3件未満 16:1015 / 06 サーバー未接続 16:1120）
struct RecommendationsView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @EnvironmentObject private var taste: TasteStore
    @EnvironmentObject private var connection: ConnectionStatus
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.isTabActive) private var isTabActive
    @State private var selectedItem: Item?
    @State private var showsFilter = false
    /// タブを開いてから、まだサーバーのおすすめを取り直していないか
    @State private var needsServerRecommendations = true

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.s12),
        GridItem(.flexible(), spacing: Theme.Spacing.s12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: Theme.Spacing.s20) {
                    if viewModel.isPersonalized {
                        diagnosis
                        sectionHeader(title: "あなたへのおすすめ", subtitle: recommendationSubtitle)
                        typeChips
                    } else {
                        personalizeProgress
                        popularHeader
                    }
                    grid
                }
                .padding(.horizontal, Theme.Spacing.s16)
                .padding(.top, Theme.Spacing.s4)
                .padding(.bottom, Theme.Spacing.s24)
            }
        }
        .background(Theme.Colors.surface)
        .sheet(isPresented: $showsFilter) { FilterSheet() }
        .fullScreenCover(item: $selectedItem) { item in
            if let url = item.productUrl {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        // 表示中のときだけ取りに行く（隠れている間に LIKE のたびに送り直さない）。
        // タブを開いたときはおすすめと診断の両方、開いている間にハートで LIKE が増減したときは、
        // 一覧が並び替わらないよう診断だけ取り直す
        .task(id: "\(viewModel.likedItems.count)-\(isTabActive)") {
            guard isTabActive else {
                needsServerRecommendations = true
                return
            }
            await loadFromServer(includingRecommendations: needsServerRecommendations)
        }
        .onChange(of: isTabActive) { _, isActive in
            // ハートで付け外しした分を、開き直したときに反映する
            if isActive { viewModel.refreshRecommendations() }
        }
    }

    /// 手元の LIKE をサーバーへ送り直してから、サーバーのおすすめと AI 診断を取りに行く
    /// （先に取ると、届く前の LIKE で計算される）。どちらも失敗したら端末内の表示のまま
    private func loadFromServer(includingRecommendations: Bool) async {
        guard viewModel.isPersonalized else { return }
        // 送り直しは並列・タイムアウト5秒なので、サーバーが止まっていても数秒で抜ける
        await ActionService.syncLikes(itemCodes: viewModel.likedItems.map(\.itemCode))
        guard !Task.isCancelled else { return }
        let likeCount = viewModel.likedItems.count
        if includingRecommendations {
            async let recommendations: Void = viewModel.loadServerRecommendations()
            async let diagnosis: Void = taste.load(likeCount: likeCount)
            _ = await (recommendations, diagnosis)
            // 途中で取り消されたら、次の実行でもう一度おすすめを取る
            if !Task.isCancelled { needsServerRecommendations = false }
        } else {
            await taste.load(likeCount: likeCount)
        }
    }

    private var recommendationSubtitle: String {
        switch viewModel.recommendationSource {
        case .server:  return "LIKEした服とスタイル・色・シルエットが近い順"
        case .local:   return "LIKEした服とジャンルが同じで、価格が近い順"
        case .popular: return "レビューの多い順"
        }
    }

    // MARK: - Header（Top app bar large）

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
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
            .padding(.horizontal, Theme.Spacing.s4)
            .padding(.top, Theme.Spacing.s4)

            VStack(alignment: .leading, spacing: 2) {
                Text("おすすめ")
                    .typography(Theme.Typography.headlineMedium)
                    .foregroundStyle(Theme.Colors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                Text(viewModel.isPersonalized
                     ? "LIKEした\(viewModel.likedItems.count)件をもとに選んでいます"
                     : "LIKEすると、あなた向けに並び替わります")
                    .typography(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
            }
            .padding(.horizontal, Theme.Spacing.s16)
            .padding(.bottom, Theme.Spacing.s12)
        }
    }

    // MARK: - AI スタイル診断（つながらないときは未接続カード）

    @ViewBuilder
    private var diagnosis: some View {
        if connection.state == .disconnected {
            OfflineCard(lastSuccessAt: connection.lastSuccessAt, isRetrying: connection.isRetrying) {
                Task {
                    await connection.retry()
                    if connection.state == .connected {
                        await loadFromServer(includingRecommendations: true)
                    }
                }
            }
        } else {
            TasteCard(likeCount: viewModel.likedItems.count, text: taste.text, isFetching: taste.isFetching)
        }
    }

    // MARK: - LIKE 3件未満（05）

    private var personalizeProgress: some View {
        let count = viewModel.likedItems.count
        let threshold = SwipeViewModel.personalizeThreshold
        return VStack(alignment: .leading, spacing: Theme.Spacing.s16) {
            HStack(spacing: Theme.Spacing.s16) {
                ProgressRing(value: count, total: threshold)
                VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                    Text("あと\(threshold - count)件LIKEすると、あなた向けに並び替わります")
                        .typography(Theme.Typography.titleMedium)
                        .foregroundStyle(Theme.Colors.onSurface)
                    Text("LIKEした服とスタイル・色・シルエットが近い商品を優先して並べます")
                        .typography(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.onSurfaceVariant)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                navigation.selectedTab = .swipe
            } label: {
                HStack(spacing: Theme.Spacing.s8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 17, weight: .medium))
                    Text("スワイプを続ける")
                        .typography(Theme.Typography.titleMedium)
                }
                .foregroundStyle(Theme.Colors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s16)
                .background(Capsule().fill(Theme.Colors.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.s20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.extraLarge)
                .fill(Theme.Colors.surfaceContainerLow)
        )
    }

    private var popularHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("いま人気のアイテム")
                .typography(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.Colors.onSurface)
            Spacer()
            Text("レビューの多い順")
                .typography(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
        }
    }

    // MARK: - 一覧

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .typography(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.Colors.onSurface)
            Text(subtitle)
                .typography(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
        }
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s8) {
                ForEach(UserProfile.ItemType.allCases) { type in
                    FilterChip(label: type.displayName, isSelected: viewModel.recommendationType == type) {
                        viewModel.recommendationType = type
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s16)
        }
        .padding(.horizontal, -Theme.Spacing.s16)
    }

    @ViewBuilder
    private var grid: some View {
        if viewModel.recommendedItems.isEmpty {
            Text("条件に合うおすすめがありません")
                .typography(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s32)
        } else {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.s12) {
                ForEach(viewModel.recommendedItems) { item in
                    let isLiked = viewModel.isLiked(item)
                    ProductCard(
                        item: item,
                        isLiked: isLiked,
                        reason: viewModel.recommendationReason(for: item),
                        onLikeTap: { viewModel.setLiked(item, !isLiked) }
                    )
                    .onTapGesture { selectedItem = item }
                }
            }
        }
    }
}

import SwiftUI

/// LIKE 画面（Figma: 07 LIKE 17:1121 / 08 LIKE — 選択モード 17:1244）
struct LikesView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @EnvironmentObject private var navigation: AppNavigation
    @State private var typeFilter: UserProfile.ItemType = .all
    @State private var selectedIDs: Set<String> = []
    @State private var selectedItem: Item?

    private var isSelecting: Bool { navigation.isSelectingLikes }

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.s12),
        GridItem(.flexible(), spacing: Theme.Spacing.s12),
    ]

    /// 新しく LIKE したものを先に
    private var likedNewestFirst: [Item] { viewModel.likedItems.reversed() }

    private var visibleItems: [Item] {
        guard typeFilter != .all else { return likedNewestFirst }
        return likedNewestFirst.filter { MockDataService.itemType(for: $0.id) == typeFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if viewModel.likedItems.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s16) {
                        countChips
                        grid
                    }
                    .padding(.horizontal, Theme.Spacing.s16)
                    .padding(.top, Theme.Spacing.s4)
                    .padding(.bottom, Theme.Spacing.s24)
                }
            }
        }
        .background(Theme.Colors.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting { selectionActionBar }
        }
        .fullScreenCover(item: $selectedItem) { item in
            if let url = item.productUrl {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        .onChange(of: viewModel.likedItems.count) { _, count in
            // 種別ごとの件数が0になったら「すべて」に戻す
            if typeFilter != .all, visibleItems.isEmpty { typeFilter = .all }
            if count == 0 { endSelection() }
        }
        .onAppear {
            #if DEBUG
            if ScreenshotScenario.current == .likesSelecting {
                selectedIDs = Set(visibleItems.dropFirst().prefix(2).map(\.id))
                navigation.isSelectingLikes = true
            }
            #endif
        }
        .animation(.easeOut(duration: 0.2), value: isSelecting)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if isSelecting {
                    Button("完了") { endSelection() }
                        .typography(Theme.Typography.labelLarge)
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.horizontal, Theme.Spacing.s12)
                        .padding(.vertical, 10)
                        .frame(height: 48)
                } else {
                    Button {
                        beginSelection(with: nil)
                    } label: {
                        Image(systemName: "checklist")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Theme.Colors.onSurfaceVariant)
                            .frame(width: 48, height: 48)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.likedItems.isEmpty)
                    .opacity(viewModel.likedItems.isEmpty ? 0.38 : 1)
                    .accessibilityLabel("選択")
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
            .padding(.top, Theme.Spacing.s4)

            VStack(alignment: .leading, spacing: 2) {
                Text(isSelecting ? "\(selectedIDs.count)件を選択中" : "LIKE")
                    .typography(Theme.Typography.headlineMedium)
                    .foregroundStyle(Theme.Colors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                Text(isSelecting
                     ? "タップで選択・まとめてLIKEから外せます"
                     : "\(viewModel.likedItems.count)件・長押しで選択")
                    .typography(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
            }
            .padding(.horizontal, Theme.Spacing.s16)
            .padding(.bottom, Theme.Spacing.s12)
        }
    }

    // MARK: - 件数チップ（0件の種別は出さない）

    private var countChips: some View {
        let types = UserProfile.ItemType.allCases.filter { $0 != .all }
        let counts = Dictionary(grouping: viewModel.likedItems.compactMap { MockDataService.itemType(for: $0.id) }, by: { $0 })
            .mapValues(\.count)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s8) {
                FilterChip(label: "すべて \(viewModel.likedItems.count)", isSelected: typeFilter == .all) {
                    typeFilter = .all
                }
                ForEach(types.filter { (counts[$0] ?? 0) > 0 }) { type in
                    FilterChip(label: "\(type.displayName) \(counts[type] ?? 0)", isSelected: typeFilter == type) {
                        typeFilter = type
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s16)
        }
        .padding(.horizontal, -Theme.Spacing.s16)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s12) {
            ForEach(visibleItems) { item in
                ProductCard(
                    item: item,
                    isLiked: true,
                    selection: isSelecting ? (selectedIDs.contains(item.id) ? .on : .off) : .none,
                    onLikeTap: { viewModel.unlike(item: item) }
                )
                .onTapGesture {
                    if isSelecting { toggle(item) } else { selectedItem = item }
                }
                .onLongPressGesture {
                    if !isSelecting { beginSelection(with: item) }
                }
                .accessibilityAddTraits(isSelecting && selectedIDs.contains(item.id) ? .isSelected : [])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.s16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.outline)
            Text("まだLIKEした商品がありません")
                .typography(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    // MARK: - 選択モードの操作バー（ナビゲーションバーの代わりに出す）

    private var selectionActionBar: some View {
        HStack {
            Button("すべて選択") {
                selectedIDs = Set(visibleItems.map(\.id))
            }
            .typography(Theme.Typography.labelLarge)
            .foregroundStyle(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 10)

            Spacer()

            Button {
                viewModel.unlike(itemIDs: selectedIDs)
                endSelection()
            } label: {
                HStack(spacing: Theme.Spacing.s8) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                    Text("LIKEから外す（\(selectedIDs.count)）")
                        .typography(Theme.Typography.labelLarge)
                }
                .foregroundStyle(Theme.Colors.onError)
                .padding(.leading, Theme.Spacing.s16)
                .padding(.trailing, Theme.Spacing.s24)
                .padding(.vertical, Theme.Spacing.s12)
                .background(Capsule().fill(Theme.Colors.error))
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
            .opacity(selectedIDs.isEmpty ? 0.38 : 1)
        }
        .padding(.leading, Theme.Spacing.s8)
        .padding(.trailing, Theme.Spacing.s16)
        .padding(.vertical, Theme.Spacing.s12)
        .background(Theme.Colors.surfaceContainer.ignoresSafeArea(edges: .bottom))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Selection

    private func beginSelection(with item: Item?) {
        selectedIDs = item.map { [$0.id] } ?? []
        navigation.isSelectingLikes = true
    }

    private func endSelection() {
        navigation.isSelectingLikes = false
        selectedIDs = []
    }

    private func toggle(_ item: Item) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }
}

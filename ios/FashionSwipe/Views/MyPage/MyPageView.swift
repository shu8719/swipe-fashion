import SwiftUI

/// マイページ（Figma: 09 マイページ 17:1356 / 10 すべて削除の確認 17:1448）
struct MyPageView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @EnvironmentObject private var taste: TasteStore
    @EnvironmentObject private var connection: ConnectionStatus
    @State private var showsFilter = false
    @State private var showsNameEditor = false
    @State private var nameDraft = ""
    @State private var showsDeleteAll = false
    @State private var linkToOpen: LinkTarget?

    private struct LinkTarget: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private static let rakutenWebServiceURL = URL(string: "https://webservice.rakuten.co.jp/")!
    private static let rakutenDevelopersURL = URL(string: "https://developers.rakuten.com/")!

    private static let syncTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 48 + Theme.Spacing.s4)
                Text("マイページ")
                    .typography(Theme.Typography.headlineMedium)
                    .foregroundStyle(Theme.Colors.onSurface)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, Theme.Spacing.s16)
                    .padding(.bottom, Theme.Spacing.s12)

                VStack(alignment: .leading, spacing: Theme.Spacing.s20) {
                    profile
                    group("表示する商品") {
                        Button { showsFilter = true } label: {
                            row(title: "絞り込み条件", value: filterSummary, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                    group("データ") {
                        serverRow
                        divider
                        deleteAllRow
                    }
                    group("このアプリについて") {
                        Button { linkToOpen = LinkTarget(url: Self.rakutenWebServiceURL) } label: {
                            row(title: "商品データ", value: "楽天市場 商品検索API", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        divider
                        row(title: "バージョン", value: appVersion, showsChevron: false)
                    }
                    Button {
                        linkToOpen = LinkTarget(url: Self.rakutenDevelopersURL)
                    } label: {
                        Text("Supported by Rakuten Developers")
                            .typography(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.Colors.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.s16)
                .padding(.top, Theme.Spacing.s4)
                .padding(.bottom, Theme.Spacing.s24)
            }
        }
        .background(Theme.Colors.surface)
        .sheet(isPresented: $showsFilter) { FilterSheet() }
        .fullScreenCover(item: $linkToOpen) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .alert("名前を編集", isPresented: $showsNameEditor) {
            TextField("表示名", text: $nameDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                var p = viewModel.profile
                p.displayName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.updateProfile(p)
            }
        }
        .confirmDialog(
            isPresented: $showsDeleteAll,
            icon: "trash",
            title: "LIKEを\nすべて削除しますか？",
            message: "LIKEした\(viewModel.likedItems.count)件がすべて外れ、おすすめも最初の状態に戻ります。この操作は取り消せません。",
            confirmTitle: "すべて削除"
        ) {
            // TODO: サーバーに LIKE を外す API ができたら、サーバー側の LIKE も消す
            viewModel.clearAllLikes()
            taste.clear()
        }
        .onAppear {
            #if DEBUG
            if ScreenshotScenario.current == .myPageDeleteAll {
                withoutAnimation { showsDeleteAll = true }
            }
            #endif
        }
    }

    // MARK: - Profile

    private var displayName: String { viewModel.profile.displayName }

    private var profile: some View {
        HStack(spacing: Theme.Spacing.s16) {
            Group {
                if let initial = displayName.first {
                    Text(String(initial))
                        .typography(Theme.Typography.titleLarge)
                } else {
                    Image(systemName: "person")
                        .font(.system(size: 22, weight: .medium))
                }
            }
            .foregroundStyle(Theme.Colors.onPrimaryContainer)
            .frame(width: 56, height: 56)
            .background(Circle().fill(Theme.Colors.primaryContainer))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? "名前未設定" : displayName)
                    .typography(Theme.Typography.titleLarge)
                    .foregroundStyle(displayName.isEmpty ? Theme.Colors.onSurfaceVariant : Theme.Colors.onSurface)
                    .lineLimit(1)
                Text("LIKE \(viewModel.likedItems.count)件 ・ スタイル診断 \(taste.diagnosisCount)回")
                    .typography(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("編集") {
                nameDraft = displayName
                showsNameEditor = true
            }
            .typography(Theme.Typography.labelLarge)
            .foregroundStyle(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 10)
        }
        .padding(Theme.Spacing.s16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.extraLarge)
                .fill(Theme.Colors.surfaceContainerLow)
        )
    }

    // MARK: - データ

    private var serverRow: some View {
        HStack(spacing: Theme.Spacing.s16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("AI診断サーバー")
                    .typography(Theme.Typography.bodyLarge)
                    .foregroundStyle(Theme.Colors.onSurface)
                Text(connection.lastSuccessAt.map { "最終同期 \(Self.syncTimeFormatter.string(from: $0))" } ?? "未同期")
                    .typography(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            serverStatusPill
        }
        .padding(.horizontal, Theme.Spacing.s16)
        .padding(.vertical, Theme.Spacing.s12)
        .accessibilityElement(children: .combine)
    }

    private var serverStatusPill: some View {
        let (label, background, foreground, dot): (String, Color, Color, Color) = {
            switch connection.state {
            case .connected:
                return ("接続中", Theme.Colors.tertiaryContainer, Theme.Colors.onTertiaryContainer, Theme.Colors.tertiary)
            case .disconnected:
                return ("未接続", Theme.Colors.errorContainer, Theme.Colors.onErrorContainer, Theme.Colors.error)
            case .unknown:
                return ("確認中", Theme.Colors.surfaceContainerHigh, Theme.Colors.onSurfaceVariant, Theme.Colors.outline)
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(label)
                .typography(Theme.Typography.labelLarge)
                .foregroundStyle(foreground)
        }
        .padding(.leading, 10)
        .padding(.trailing, Theme.Spacing.s12)
        .padding(.vertical, Theme.Spacing.s4)
        .background(Capsule().fill(background))
    }

    private var deleteAllRow: some View {
        Button {
            withoutAnimation { showsDeleteAll = true }
        } label: {
            HStack(spacing: Theme.Spacing.s16) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 24)
                Text("LIKEをすべて削除")
                    .typography(Theme.Typography.bodyLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Theme.Colors.error)
            .padding(Theme.Spacing.s16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.likedItems.isEmpty)
        .opacity(viewModel.likedItems.isEmpty ? 0.38 : 1)
    }

    // MARK: - Helpers

    private var filterSummary: String {
        let p = viewModel.profile
        return "\(p.category.displayName)・\(p.itemType.displayName)・\(p.priceRange.displayName)"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.outlineVariant)
            .frame(height: 1)
            .padding(.horizontal, Theme.Spacing.s16)
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            Text(title)
                .typography(Theme.Typography.labelLarge)
                .foregroundStyle(Theme.Colors.primary)
                .padding(.leading, Theme.Spacing.s4)
            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.large)
                        .fill(Theme.Colors.surfaceContainerLow)
                )
        }
    }

    private func row(title: String, value: String, showsChevron: Bool) -> some View {
        HStack(spacing: Theme.Spacing.s16) {
            Text(title)
                .typography(Theme.Typography.bodyLarge)
                .foregroundStyle(Theme.Colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .typography(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
            }
        }
        .padding(Theme.Spacing.s16)
        .contentShape(Rectangle())
    }
}

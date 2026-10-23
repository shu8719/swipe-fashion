import SwiftUI

/// 絞り込みシート（Figma: 03 絞り込みシート 16:927）。スワイプ画面とマイページから開く
struct FilterSheet: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UserProfile = .default

    var body: some View {
        let count = viewModel.matchingItemCount(for: draft)

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s20) {
                HStack {
                    Text("絞り込み")
                        .typography(Theme.Typography.titleLarge)
                        .foregroundStyle(Theme.Colors.onSurface)
                    Spacer()
                    Button("リセット") {
                        draft.category = .all
                        draft.itemType = .all
                        draft.priceRange = .all
                    }
                    .typography(Theme.Typography.labelLarge)
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, Theme.Spacing.s12)
                    .padding(.vertical, 10)
                }

                group("カテゴリ") {
                    SegmentedButton(options: UserProfile.Category.allCases, selection: $draft.category) {
                        $0.displayName
                    }
                }

                group("アイテム") {
                    FlowLayout {
                        ForEach(UserProfile.ItemType.allCases) { type in
                            FilterChip(label: type.displayName, isSelected: draft.itemType == type) {
                                draft.itemType = type
                            }
                        }
                    }
                }

                group("価格帯") {
                    FlowLayout {
                        ForEach(UserProfile.PriceRange.allCases) { range in
                            FilterChip(label: range.displayName, isSelected: draft.priceRange == range) {
                                draft.priceRange = range
                            }
                        }
                    }
                }

                VStack(spacing: Theme.Spacing.s8) {
                    if count == 0 {
                        Text("条件に合う商品がありません")
                            .typography(Theme.Typography.bodyMedium)
                            .foregroundStyle(Theme.Colors.onSurfaceVariant)
                    }
                    Button {
                        viewModel.updateProfile(draft)
                        dismiss()
                    } label: {
                        Text("この条件で \(count)件 を見る")
                            .typography(Theme.Typography.titleMedium)
                            .foregroundStyle(Theme.Colors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s16)
                            .background(Capsule().fill(Theme.Colors.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(count == 0)
                    .opacity(count == 0 ? 0.38 : 1)
                }
            }
            .padding(.horizontal, Theme.Spacing.s24)
            .padding(.top, Theme.Spacing.s32)
            .padding(.bottom, Theme.Spacing.s8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.extraLarge)
        .presentationBackground(Theme.Colors.surfaceContainerLow)
        .onAppear { draft = viewModel.profile }
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s8) {
            Text(title)
                .typography(Theme.Typography.labelLarge)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
            content()
        }
    }
}

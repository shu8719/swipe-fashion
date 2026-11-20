import SwiftUI

/// 2列グリッド用の商品カード（Figma: Product card 3:71）
struct ProductCard: View {
    enum Selection { case none, off, on }

    let item: Item
    var isLiked = false
    /// 画像の左下に出すおすすめ理由（nil なら出さない）
    var reason: String? = nil
    /// 選択モードでは右上の LIKE ボタンを丸いチェックに置き換える
    var selection: Selection = .none
    var onLikeTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                Text(item.shopName)
                    .typography(Theme.Typography.labelSmall)
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
                    .lineLimit(1)
                Text(item.cleanName)
                    .typography(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.onSurface)
                    .lineLimit(2, reservesSpace: true)
                Text("¥\(item.itemPrice.formatted())")
                    .typography(Theme.Typography.titleMedium)
                    .foregroundStyle(Theme.Colors.onSurface)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.top, Theme.Spacing.s12)
            .padding(.bottom, Theme.Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Colors.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay {
            if selection == .on {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Colors.primary, lineWidth: 3)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Image（楽天の画像は正方形なので 1:1）

    private var image: some View {
        Theme.Colors.surfaceContainerHighest
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedAsyncImage(url: item.largeImageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "tshirt")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.Colors.onSurfaceVariant)
                    default:
                        Color.clear
                    }
                }
            }
            .clipped()
            .overlay(alignment: .topTrailing) { topTrailingControl }
            .overlay(alignment: .bottomLeading) {
                if let reason {
                    Text(reason)
                        .typography(Theme.Typography.labelSmall)
                        .foregroundStyle(Theme.Colors.onSurface)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, Theme.Spacing.s4)
                        .background(Capsule().fill(Theme.Colors.surfaceContainerLowest))
                        .padding(Theme.Spacing.s8)
                }
            }
    }

    @ViewBuilder
    private var topTrailingControl: some View {
        switch selection {
        case .none:
            Button {
                onLikeTap?()
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isLiked ? Theme.Colors.like : Theme.Colors.onSurfaceVariant)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.Colors.surfaceContainerLowest))
            }
            .buttonStyle(.plain)
            .disabled(onLikeTap == nil)
            .accessibilityLabel(isLiked ? "LIKEから外す" : "LIKE")
            .padding(Theme.Spacing.s8)
        case .off:
            Circle()
                .strokeBorder(Theme.Colors.outline, lineWidth: 2)
                .background(Circle().fill(Theme.Colors.surfaceContainerLowest))
                .frame(width: 28, height: 28)
                .padding(Theme.Spacing.s8)
                .accessibilityHidden(true)
        case .on:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.onPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.Colors.primary))
                .padding(.top, Theme.Spacing.s8)
                .padding(.trailing, 5)
                .accessibilityHidden(true)
        }
    }
}

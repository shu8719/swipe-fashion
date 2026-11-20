import SwiftUI

/// スワイプ画面のカード（Figma: Swipe card 3:117）
struct SwipeCard: View {
    let item: Item
    /// ドラッグの進み具合。プラスは LIKE 方向、マイナスは SKIP 方向（-1...1）
    var dragProgress: CGFloat = 0
    var onOpenProduct: () -> Void = {}

    private var likeAmount: CGFloat { max(0, min(dragProgress, 1)) }
    private var skipAmount: CGFloat { max(0, min(-dragProgress, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
            content
        }
        .background(Theme.Colors.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.extraLarge))
        .elevation(.level2)
    }

    // MARK: - Image

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
                            .font(.system(size: 80))
                            .foregroundStyle(Theme.Colors.onSurfaceVariant)
                    default:
                        Color.clear
                    }
                }
            }
            .overlay {
                // ドラッグ方向の色を最大 14% かぶせる
                (likeAmount > 0 ? Theme.Colors.like : Theme.Colors.skip)
                    .opacity(0.14 * max(likeAmount, skipAmount))
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                if let tag = ProductCatalog.itemType(for: item.id)?.displayName {
                    Text(tag)
                        .typography(Theme.Typography.labelMedium)
                        .foregroundStyle(Theme.Colors.onSurface)
                        .padding(.horizontal, Theme.Spacing.s12)
                        .padding(.vertical, Theme.Spacing.s4)
                        .background(Capsule().fill(Theme.Colors.surfaceContainerLowest))
                        .padding(Theme.Spacing.s16)
                }
            }
            .overlay(alignment: .topLeading) {
                SwipeStamp(kind: .like)
                    .rotationEffect(.degrees(-12))
                    .padding(.leading, Theme.Spacing.s24)
                    .padding(.top, 52)
                    .opacity(likeAmount)
            }
            .overlay(alignment: .topTrailing) {
                SwipeStamp(kind: .skip)
                    .rotationEffect(.degrees(12))
                    .padding(.trailing, Theme.Spacing.s24)
                    .padding(.top, 56)
                    .opacity(skipAmount)
            }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            Text(item.shopName)
                .typography(Theme.Typography.labelMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
                .lineLimit(1)
            Text(item.cleanName)
                .typography(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.Colors.onSurface)
                .lineLimit(2, reservesSpace: true)
            HStack(alignment: .center) {
                Text("¥\(item.itemPrice.formatted())")
                    .typography(Theme.Typography.headlineSmall)
                    .foregroundStyle(Theme.Colors.onSurface)
                Spacer(minLength: Theme.Spacing.s8)
                Button(action: onOpenProduct) {
                    HStack(spacing: Theme.Spacing.s4) {
                        Text("商品を見る")
                            .typography(Theme.Typography.labelLarge)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, Theme.Spacing.s12)
                    .padding(.vertical, Theme.Spacing.s8)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Theme.Spacing.s8)
        }
        .padding(.horizontal, Theme.Spacing.s20)
        .padding(.top, Theme.Spacing.s16)
        .padding(.bottom, Theme.Spacing.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// ドラッグ中に出る LIKE / SKIP のスタンプ
private struct SwipeStamp: View {
    enum Kind { case like, skip }
    let kind: Kind

    var body: some View {
        let isLike = kind == .like
        let color = isLike ? Theme.Colors.like : Theme.Colors.skip
        HStack(spacing: 6) {
            Image(systemName: isLike ? "heart.fill" : "xmark")
                .font(.system(size: isLike ? 24 : 22, weight: .bold))
            Text(isLike ? "LIKE" : "SKIP")
                .font(.system(size: 32, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.leading, Theme.Spacing.s12)
        .padding(.trailing, Theme.Spacing.s16)
        .padding(.vertical, Theme.Spacing.s4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .fill(isLike ? Theme.Colors.likeContainer : Theme.Colors.errorContainer)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(color, lineWidth: 3)
        )
        .accessibilityHidden(true)
    }
}

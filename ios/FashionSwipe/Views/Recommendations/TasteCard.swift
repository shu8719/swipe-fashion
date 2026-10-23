import SwiftUI

/// AI スタイル診断カード（Figma: 04 おすすめ 4:190）
struct TasteCard: View {
    let likeCount: Int
    let text: String?
    let isFetching: Bool

    private var meta: String {
        let interval = SwipeViewModel.tasteInterval
        guard likeCount >= interval else {
            return "あと\(interval - likeCount)件のLIKEで診断できます"
        }
        // サーバーは分析に使った件数を返さないので、10件ごとに作り直される前提で数える
        let analyzed = likeCount / interval * interval
        let remaining = interval - likeCount % interval
        return "LIKE \(analyzed)件から分析 ・ あと\(remaining)件で更新"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            HStack(spacing: Theme.Spacing.s12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.Colors.surfaceContainerLowest))
                VStack(alignment: .leading, spacing: 0) {
                    Text("AIスタイル診断")
                        .typography(Theme.Typography.titleMedium)
                    Text(meta)
                        .typography(Theme.Typography.bodySmall)
                }
                .foregroundStyle(Theme.Colors.onPrimaryContainer)
            }

            Group {
                if let text {
                    Text(text)
                } else if isFetching {
                    HStack(spacing: Theme.Spacing.s8) {
                        ProgressView().controlSize(.small)
                        Text("AIがあなたのスタイルを分析中...")
                    }
                } else if likeCount < SwipeViewModel.tasteInterval {
                    Text("LIKEが10件たまると、AIがあなたの好みを文章で説明します。")
                } else {
                    Text("AIスタイル診断を準備中です。")
                }
            }
            .typography(Theme.Typography.bodyMedium)
            .foregroundStyle(Theme.Colors.onPrimaryContainer)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.s16)
        .padding(.top, Theme.Spacing.s16)
        .padding(.bottom, Theme.Spacing.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .fill(Theme.Colors.primaryContainer)
        )
        .accessibilityElement(children: .combine)
    }
}

/// AI 診断サーバーにつながらないときのカード（Figma: 06 おすすめ — サーバー未接続 16:1164）
struct OfflineCard: View {
    let lastSuccessAt: Date?
    let isRetrying: Bool
    let onRetry: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d H:mm"
        return formatter
    }()

    private var lastConnectedText: String {
        guard let lastSuccessAt else { return "まだ一度もつながっていません" }
        return "最後につながった時刻 \(Self.timeFormatter.string(from: lastSuccessAt))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s12) {
            HStack(spacing: Theme.Spacing.s12) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.onErrorContainer)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.Colors.errorContainer))
                VStack(alignment: .leading, spacing: 0) {
                    Text("AI診断サーバーにつながりません")
                        .typography(Theme.Typography.titleMedium)
                        .foregroundStyle(Theme.Colors.onSurface)
                    Text(lastConnectedText)
                        .typography(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.onSurfaceVariant)
                }
            }

            Text("おすすめは端末内のデータで表示しています。つながると、AIスタイル診断が表示されます。")
                .typography(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                HStack(spacing: Theme.Spacing.s8) {
                    if isRetrying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text("再試行")
                        .typography(Theme.Typography.labelLarge)
                }
                .foregroundStyle(Theme.Colors.onSecondaryContainer)
                .padding(.leading, Theme.Spacing.s16)
                .padding(.trailing, Theme.Spacing.s24)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.Colors.secondaryContainer))
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)
        }
        .padding(Theme.Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .fill(Theme.Colors.surfaceContainerLow)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .strokeBorder(Theme.Colors.outlineVariant, lineWidth: 1)
        )
    }
}

/// n / total の進捗リング（Figma: 05 の Progress ring）。値が変わるので図形で描く
struct ProgressRing: View {
    let value: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.secondaryContainer, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(value) / CGFloat(max(total, 1)))
                .stroke(Theme.Colors.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)/\(total)")
                .typography(Theme.Typography.titleSmall)
                .foregroundStyle(Theme.Colors.onSurface)
        }
        .frame(width: 64, height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total)件中\(value)件")
    }
}

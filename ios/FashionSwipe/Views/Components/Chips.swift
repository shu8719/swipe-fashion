import SwiftUI

/// M3 Filter chip（Figma: Filter chip 3:49）
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(label)
                    .typography(Theme.Typography.labelLarge)
                    .lineLimit(1)
            }
            .padding(.leading, isSelected ? Theme.Spacing.s8 : Theme.Spacing.s16)
            .padding(.trailing, Theme.Spacing.s16)
            .frame(height: 32)
            .foregroundStyle(isSelected ? Theme.Colors.onSecondaryContainer : Theme.Colors.onSurfaceVariant)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(isSelected ? Theme.Colors.secondaryContainer : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .strokeBorder(isSelected ? .clear : Theme.Colors.outlineVariant, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// M3 Assist chip（Figma: Assist chip 3:50）。今の条件やタグの表示に使う
struct AssistChip: View {
    let icon: String?
    let label: String
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: Theme.Spacing.s8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Colors.primary)
            }
            Text(label)
                .typography(Theme.Typography.labelLarge)
                .foregroundStyle(Theme.Colors.onSurface)
                .lineLimit(1)
        }
        .padding(.leading, icon == nil ? Theme.Spacing.s16 : Theme.Spacing.s8)
        .padding(.trailing, Theme.Spacing.s16)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.Colors.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .strokeBorder(Theme.Colors.outlineVariant, lineWidth: 1)
        )

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

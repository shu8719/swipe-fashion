import SwiftUI

/// M3 Segmented button（高さ40・完全な丸・Outline の枠線。選択中は Secondary Container＋チェック）
struct SegmentedButton<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.Colors.outline)
                        .frame(width: 1)
                }
                segment(option)
            }
        }
        .frame(height: 40)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Colors.outline, lineWidth: 1))
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            HStack(spacing: Theme.Spacing.s8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(label(option))
                    .typography(Theme.Typography.labelLarge)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.Colors.onSecondaryContainer : Theme.Colors.onSurface)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Theme.Colors.secondaryContainer : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

import SwiftUI

/// M3 Navigation bar（Figma: Navigation bar 3:20 / Nav item 3:19）
struct AppNavigationBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                NavItem(tab: tab, isSelected: tab == selection) {
                    selection = tab
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .background(Theme.Colors.surfaceContainer.ignoresSafeArea(edges: .bottom))
    }
}

private struct NavItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.s4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 56, height: 32)
                    .foregroundStyle(isSelected ? Theme.Colors.onSecondaryContainer : Theme.Colors.onSurfaceVariant)
                    .background(
                        Capsule().fill(isSelected ? Theme.Colors.secondaryContainer : .clear)
                    )
                Text(tab.title)
                    .typography(Theme.Typography.labelMedium)
                    .foregroundStyle(isSelected ? Theme.Colors.onSurface : Theme.Colors.onSurfaceVariant)
            }
            .padding(.top, Theme.Spacing.s12)
            .padding(.bottom, Theme.Spacing.s16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

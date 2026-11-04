import SwiftUI

/// M3 の確認ダイアログ（Figma: 10 マイページ — すべて削除の確認 6:332）。
/// ナビゲーションバーの上まで覆うため、背景を透明にした fullScreenCover で出す
struct ConfirmDialog: View {
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isShown = false
    @State private var isClosing = false

    var body: some View {
        ZStack {
            Theme.Colors.scrim
                .ignoresSafeArea()
                .opacity(isShown ? 1 : 0)
                .onTapGesture { close(then: onCancel) }
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.Colors.secondary)
                Text(title)
                    .typography(Theme.Typography.headlineSmall)
                    .foregroundStyle(Theme.Colors.onSurface)
                    .multilineTextAlignment(.center)
                Text(message)
                    .typography(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.s8) {
                    Spacer()
                    Button("キャンセル") { close(then: onCancel) }
                        .foregroundStyle(Theme.Colors.primary)
                    Button(confirmTitle, role: .destructive) { close(then: onConfirm) }
                        .foregroundStyle(Theme.Colors.error)
                }
                .typography(Theme.Typography.labelLarge)
                .buttonStyle(DialogTextButtonStyle())
                .padding(.top, Theme.Spacing.s8)
            }
            .padding(Theme.Spacing.s24)
            .frame(maxWidth: 312)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.extraLarge)
                    .fill(Theme.Colors.surfaceContainerHigh)
            )
            .elevation(.level3)
            .padding(.horizontal, Theme.Spacing.s24)
            .scaleEffect(isShown ? 1 : 0.92)
            .opacity(isShown ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .presentationBackground(.clear)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { isShown = true }
        }
    }

    private func close(then action: @escaping () -> Void) {
        // フェードアウト中の2回目のタップで、キャンセルと削除が両方走らないようにする
        guard !isClosing else { return }
        isClosing = true
        withAnimation(.easeIn(duration: 0.15)) { isShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { action() }
    }
}

private struct DialogTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Theme.Spacing.s12)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Theme.Colors.onSurface.opacity(configuration.isPressed ? 0.1 : 0))
            )
    }
}

extension View {
    /// 確認ダイアログを出す。下からせり上がる fullScreenCover の動きは消し、ダイアログ自身が fade / scale する
    func confirmDialog(isPresented: Binding<Bool>,
                       icon: String,
                       title: String,
                       message: String,
                       confirmTitle: String,
                       onConfirm: @escaping () -> Void) -> some View {
        fullScreenCover(isPresented: isPresented) {
            ConfirmDialog(icon: icon, title: title, message: message, confirmTitle: confirmTitle,
                          onCancel: { withoutAnimation { isPresented.wrappedValue = false } },
                          onConfirm: { withoutAnimation { isPresented.wrappedValue = false }; onConfirm() })
        }
    }
}

/// fullScreenCover の出し入れのアニメーションを止めて状態を変える
func withoutAnimation(_ change: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, change)
}

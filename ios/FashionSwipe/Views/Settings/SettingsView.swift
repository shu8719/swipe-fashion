import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: SwipeViewModel
    @State private var draft: UserProfile = .default

    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール") {
                    TextField("表示名", text: $draft.displayName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section("好きなスタイル") {
                    ForEach(UserProfile.availableStyles, id: \.self) { style in
                        Toggle(style, isOn: bindingForStyle(style))
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear { draft = viewModel.profile }
            // 絞り込みシートで条件が変わったら下書きも合わせる（古い条件で上書きしないため）
            .onChange(of: viewModel.profile) { _, newValue in draft = newValue }
            .onChange(of: draft) { _, newValue in
                viewModel.updateProfile(newValue)
            }
        }
    }

    private func bindingForStyle(_ style: String) -> Binding<Bool> {
        Binding(
            get: { draft.favoriteStyles.contains(style) },
            set: { isOn in
                if isOn {
                    if !draft.favoriteStyles.contains(style) {
                        draft.favoriteStyles.append(style)
                    }
                } else {
                    draft.favoriteStyles.removeAll { $0 == style }
                }
            }
        )
    }
}

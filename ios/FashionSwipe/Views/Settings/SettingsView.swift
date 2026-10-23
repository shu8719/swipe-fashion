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

                Section("表示カテゴリ") {
                    Picker("カテゴリ", selection: $draft.category) {
                        ForEach(UserProfile.Category.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("アイテム種別") {
                    Picker("アイテム種別", selection: $draft.itemType) {
                        ForEach(UserProfile.ItemType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("価格帯") {
                    Picker("価格帯", selection: $draft.priceRange) {
                        ForEach(UserProfile.PriceRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("好きなスタイル") {
                    ForEach(UserProfile.availableStyles, id: \.self) { style in
                        Toggle(style, isOn: bindingForStyle(style))
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear { draft = viewModel.profile }
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

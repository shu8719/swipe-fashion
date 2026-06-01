import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("ユーザーID", systemImage: "person.circle")
                        Spacer()
                        Text(authStore.userId.map { "#\($0)" } ?? "—")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text("アカウント")
                }

                Section {
                    Button(role: .destructive) {
                        authStore.logout()
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

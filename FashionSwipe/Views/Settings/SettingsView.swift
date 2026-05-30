import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "gearshape")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.4))
                Text("設定画面（準備中）")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("設定")
        }
    }
}

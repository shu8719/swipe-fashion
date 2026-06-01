import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    Text("Fashion Swipe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("好みを学習するAIファッションアプリ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("パスワード", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegistering ? "新規登録" : "ログイン")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)

                    Button {
                        withAnimation { isRegistering.toggle() }
                        errorMessage = nil
                    } label: {
                        Text(isRegistering ? "すでにアカウントをお持ちの方はこちら" : "アカウントを作成する")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: AuthService.AuthResponse
            if isRegistering {
                res = try await AuthService.register(email: email, password: password)
            } else {
                res = try await AuthService.login(email: email, password: password)
            }
            authStore.save(token: res.token, userId: res.user_id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentPurple.opacity(0.35),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: AppColors.accentPurple.opacity(0.6), radius: 24, x: 0, y: 0)

                VStack(spacing: 8) {
                    Text("Willkommen bei Sleepyflow")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Melde dich an, um loszulegen.\nDeine Daten bleiben komplett auf diesem Gerät.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            authManager.handleAppleSignIn(credential: credential)
                        }
                    case .failure(let error):
                        print("Sign in with Apple failed: \(error.localizedDescription)")
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 32)

                Button(action: { authManager.signInWithGoogle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Mit Google anmelden")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .floatingGlass(cornerRadius: 14)
                .padding(.horizontal, 32)

                Label("Lokal gespeichert, nichts wird an einen Server gesendet.", systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))

                Spacer(minLength: 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}

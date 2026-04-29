import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: MDSpacing.xl) {
                Spacer()

                VStack(spacing: MDSpacing.md) {
                    Text("MindDuel")
                        .mdStyle(.display)
                    Text("tagline", bundle: nil)
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MDSpacing.lg)
                }

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    guard case .success(let auth) = result,
                          let credential = auth.credential as? ASAuthorizationAppleIDCredential
                    else { return }
                    AuthService.handleCredential(credential, authState: authState)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }
}

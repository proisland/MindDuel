import AuthenticationServices

struct AuthService {
    @MainActor static func handleCredential(
        _ credential: ASAuthorizationAppleIDCredential,
        authState: AuthState
    ) {
        authState.completeSignIn(userID: credential.user)
    }
}

import AuthenticationServices

struct AuthService {
    static func handleCredential(
        _ credential: ASAuthorizationAppleIDCredential,
        authState: AuthState
    ) {
        authState.completeSignIn(userID: credential.user)
    }
}

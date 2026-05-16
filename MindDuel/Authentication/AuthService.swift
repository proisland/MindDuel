import AuthenticationServices
import Foundation

@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()
    private override init() {}

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    /// Triggers Sign in with Apple and returns the authorization result.
    func signInWithApple() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Authenticates with backend using the Apple id_token and returns the userId.
    /// Returns `isNew = true` when a username still needs to be chosen.
    func authenticate(with authorization: ASAuthorization) async throws -> (userId: String, isNew: Bool) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else { throw AuthError.missingToken }

        struct AppleAuthBody: Encodable {
            let identityToken: String
            let locale: String
        }

        let response: AuthResponse = try await APIClient.shared.post(
            "auth/apple",
            body: AppleAuthBody(identityToken: idToken, locale: Locale.current.identifier)
        )

        AuthTokenStore.shared.save(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )

        return (userId: response.user.id, isNew: response.needsUsername)
    }
}

enum AuthError: Error {
    case missingToken
    case cancelled
}

// MARK: – ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if (error as? ASAuthorizationError)?.code == .canceled {
                continuation?.resume(throwing: AuthError.cancelled)
            } else {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}

// MARK: – ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
        }
    }
}

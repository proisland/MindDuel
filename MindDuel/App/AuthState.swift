import SwiftUI

enum AuthPhase {
    case signedOut
    case needsUsername(userID: String)
    case authenticated(userID: String, username: String)
}

@MainActor
final class AuthState: ObservableObject {
    @Published var phase: AuthPhase = .signedOut
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tokenStore = AuthTokenStore.shared

    init() {
        restoreSession()
    }

    // MARK: – Sign in with Apple

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let authorization = try await AuthService.shared.signInWithApple()
            let (userId, isNew) = try await AuthService.shared.authenticate(with: authorization)
            if isNew {
                phase = .needsUsername(userID: userId)
            } else {
                try await loadProfile(userID: userId)
            }
        } catch AuthError.cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Username setup

    func setUsername(_ username: String, userID: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            struct SetUsernameBody: Encodable { let username: String }
            let response: UsernameResponse = try await APIClient.shared.post(
                "me/username",
                body: SetUsernameBody(username: username)
            )
            phase = .authenticated(userID: userID, username: response.username)
        } catch APIError.conflict(let msg) {
            errorMessage = msg
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        tokenStore.clear()
        phase = .signedOut
    }

    // MARK: – Session restore

    private func restoreSession() {
        guard tokenStore.accessToken != nil || tokenStore.refreshToken != nil else { return }
        Task {
            do {
                let user: APIUser = try await APIClient.shared.get("me")
                if let username = user.username {
                    phase = .authenticated(userID: user.id, username: username)
                } else {
                    phase = .needsUsername(userID: user.id)
                }
            } catch APIError.unauthorized {
                tokenStore.clear()
            } catch {
                // Network unavailable on launch; will retry on next launch
            }
        }
    }

    private func loadProfile(userID: String) async throws {
        let user: APIUser = try await APIClient.shared.get("me")
        if let username = user.username {
            phase = .authenticated(userID: userID, username: username)
            ProgressionStore.shared.syncWithBackend()
            Task { await SocialStore.shared.refresh() }
        } else {
            phase = .needsUsername(userID: userID)
        }
    }
}

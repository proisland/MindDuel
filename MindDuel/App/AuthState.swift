import SwiftUI

enum AuthPhase {
    case signedOut
    case needsUsername(userID: String)
    case authenticated(userID: String, username: String)
}

@MainActor
final class AuthState: ObservableObject {
    @Published var phase: AuthPhase = .signedOut

    func completeSignIn(userID: String) {
        // M2+: check backend for existing username before transitioning
        phase = .needsUsername(userID: userID)
    }

    func setUsername(_ username: String, userID: String) {
        // M2+: POST username to backend
        phase = .authenticated(userID: userID, username: username)
    }

    func signOut() {
        phase = .signedOut
    }
}

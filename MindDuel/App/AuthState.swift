import SwiftUI

enum AuthPhase {
    case signedOut
    case needsUsername(userID: String)
    case authenticated(userID: String, username: String)
}

@MainActor
final class AuthState: ObservableObject {
    private static let userIDKey   = "auth.userID"
    private static let usernameKey = "auth.username"

    @Published var phase: AuthPhase

    init() {
        let defaults = UserDefaults.standard
        if let userID   = defaults.string(forKey: Self.userIDKey),
           let username = defaults.string(forKey: Self.usernameKey) {
            phase = .authenticated(userID: userID, username: username)
        } else if let userID = defaults.string(forKey: Self.userIDKey) {
            phase = .needsUsername(userID: userID)
        } else {
            phase = .signedOut
        }
    }

    func startGuestSession() {
        let userID = UUID().uuidString
        UserDefaults.standard.set(userID, forKey: Self.userIDKey)
        phase = .needsUsername(userID: userID)
    }

    func setUsername(_ username: String, userID: String) {
        UserDefaults.standard.set(userID,    forKey: Self.userIDKey)
        UserDefaults.standard.set(username,  forKey: Self.usernameKey)
        phase = .authenticated(userID: userID, username: username)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.userIDKey)
        UserDefaults.standard.removeObject(forKey: Self.usernameKey)
        phase = .signedOut
    }
}

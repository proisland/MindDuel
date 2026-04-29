import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        switch authState.phase {
        case .signedOut:
            SignInView()
        case .needsUsername(let userID):
            UsernameSetupView(userID: userID)
        case .authenticated(_, let username):
            HomeView(username: username)
        }
    }
}

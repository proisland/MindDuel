import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var authState: AuthState
    @ObservedObject private var social = SocialStore.shared
    @ObservedObject private var multiplayer = MultiplayerStore.shared

    var body: some View {
        Group {
            switch authState.phase {
            case .signedOut:
                SignInView()
            case .needsUsername(let userID):
                UsernameSetupView(userID: userID)
            case .authenticated(_, let username):
                HomeView(username: username)
            }
        }
        .onAppear {
            syncOwnUsername()
            updateAppBadge()
        }
        .onChange(of: authPhaseDescription) { _ in syncOwnUsername() }
        .onChange(of: social.pendingRequests.count) { _ in updateAppBadge() }
        .onChange(of: multiplayer.pendingInvites.count) { _ in updateAppBadge() }
        .onChange(of: myTurnCount) { _ in updateAppBadge() }
    }

    /// Hash-able stand-in for the auth phase so SwiftUI can detect transitions
    /// (the phase enum has associated values and isn't directly Equatable).
    private var authPhaseDescription: String {
        switch authState.phase {
        case .signedOut:                              return "out"
        case .needsUsername:                          return "needs"
        case .authenticated(_, let username):         return "auth:\(username)"
        }
    }

    private func syncOwnUsername() {
        if case .authenticated(_, let username) = authState.phase {
            AvatarStore.shared.ownUsername = username
        } else {
            AvatarStore.shared.ownUsername = nil
        }
    }

    /// #114: app icon badge sums unanswered friend requests + multiplayer
    /// invites + rooms where it's currently the user's turn in the
    /// background. Anything that warrants the user picking up the phone.
    private var myTurnCount: Int {
        multiplayer.backgroundRooms.filter { $0.status == .playing && $0.isMyTurn }.count
    }

    private func updateAppBadge() {
        let total = social.pendingRequests.count
                  + multiplayer.pendingInvites.count
                  + myTurnCount
        UIApplication.shared.applicationIconBadgeNumber = total
    }
}

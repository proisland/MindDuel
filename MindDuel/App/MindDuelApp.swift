import SwiftUI

@main
struct MindDuelApp: App {
    @StateObject private var authState = AuthState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authState)
                .preferredColorScheme(.dark)
        }
    }
}

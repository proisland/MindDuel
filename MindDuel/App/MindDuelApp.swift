import SwiftUI

@main
struct MindDuelApp: App {
    @StateObject private var authState = AuthState()
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authState)
                .preferredColorScheme(preferredScheme)
        }
    }
}

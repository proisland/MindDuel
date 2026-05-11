import SwiftUI

@main
struct MindDuelApp: App {
    @StateObject private var authState = AuthState()
    @StateObject private var modeCache = ModeConfigCache.shared
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
                .environmentObject(modeCache)
                .preferredColorScheme(preferredScheme)
                .task { await onLaunch() }
        }
    }

    private func onLaunch() async {
        await modeCache.refresh()
        let allModes = ["pi", "math", "chem", "geo", "brain", "science", "history", "physics", "sport", "grammar"]
        await QuestionPackCache.shared.syncIfNeeded(modes: allModes)
    }
}

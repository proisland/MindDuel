import SwiftUI
import UserNotifications

@main
struct MindDuelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                .onReceive(NotificationCenter.default.publisher(for: .apnsTokenRegistered)) { note in
                    guard let token = note.object as? String else { return }
                    Task { await registerPushToken(token) }
                }
        }
    }

    private func onLaunch() async {
        await modeCache.refresh()
        // Sync question packs for all active modes returned by the server, so
        // newly-added modes become playable without an app update.
        let allSlugs = modeCache.serverModes.map(\.slug)
        let syncSlugs = allSlugs.isEmpty
            ? ["pi", "math", "chem", "geo", "brain", "science", "history", "physics", "sport", "grammar"]
            : allSlugs
        await QuestionPackCache.shared.syncIfNeeded(modes: syncSlugs)
        requestPushPermission()
    }

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func registerPushToken(_ token: String) async {
        do {
            struct Body: Encodable { let deviceToken: String }
            let _: Empty = try await APIClient.shared.post(
                "me/push-token",
                body: Body(deviceToken: token)
            )
        } catch {
            // Non-critical; token will be re-registered on next launch
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .apnsTokenRegistered, object: token)
    }
}

extension Notification.Name {
    static let apnsTokenRegistered = Notification.Name("apnsTokenRegistered")
}

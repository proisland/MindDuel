#if DEBUG
import Foundation

enum AppEnvironment: String, CaseIterable {
    case local      = "local"
    case staging    = "staging"
    case production = "production"

    private static let key = "app_environment"

    static var current: AppEnvironment {
        get {
            let raw = UserDefaults.standard.string(forKey: key) ?? "production"
            return AppEnvironment(rawValue: raw) ?? .production
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    var apiBaseURL: URL {
        switch self {
        case .local:      return URL(string: "http://localhost:3000/v1")!
        case .staging:    return URL(string: "https://mindduel-staging.up.railway.app/v1")!
        case .production: return URL(string: "https://mindduel-production-1180.up.railway.app/v1")!
        }
    }

    var wsBase: String {
        switch self {
        case .local:      return "ws://localhost:3000/v1/ws/rooms"
        case .staging:    return "wss://mindduel-staging.up.railway.app/v1/ws/rooms"
        case .production: return "wss://mindduel-production-1180.up.railway.app/v1/ws/rooms"
        }
    }

    var displayName: String {
        switch self {
        case .local:      return "Local"
        case .staging:    return "Staging"
        case .production: return "Production"
        }
    }
}
#endif

import Foundation

enum GameMode: String, Identifiable, Codable, CaseIterable {
    case pi
    case math
    case chemistry
    case geography

    var id: String { rawValue }

    /// Localization key for the human-readable mode name. Used by every view
    /// that lists modes so adding a new case auto-propagates everywhere (#52).
    var titleKey: String {
        switch self {
        case .pi:        return "mode_pi"
        case .math:      return "mode_math"
        case .chemistry: return "mode_chemistry"
        case .geography: return "mode_geography"
        }
    }
}

import SwiftUI

extension GameMode {
    /// Per-mode accent color used by featured cards, pills, and modal
    /// selectors. Mirrors the design system's named colors.
    var accentColor: Color {
        switch self {
        case .pi:        return .mdAccent
        case .math:      return .mdPink
        case .chemistry: return .mdGreen
        case .geography: return .mdAmber
        }
    }

    /// Deep tinted background used as the card surface for this mode.
    var deepBg: Color {
        switch self {
        case .pi:        return .mdAccentDeep
        case .math:      return .mdPinkDeep
        case .chemistry: return Color(red: 0.05, green: 0.13, blue: 0.09)   // dark green
        case .geography: return Color(red: 0.13, green: 0.08, blue: 0.03)   // dark amber
        }
    }

    var localizedTitle: String {
        switch self {
        case .pi:        return String(localized: "mode_pi")
        case .math:      return String(localized: "mode_math")
        case .chemistry: return String(localized: "mode_chemistry")
        case .geography: return String(localized: "mode_geography")
        }
    }
}

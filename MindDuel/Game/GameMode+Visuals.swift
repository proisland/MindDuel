import SwiftUI

extension GameMode {
    /// Per-mode accent color used by featured cards, pills, and modal
    /// selectors. Mirrors the design system's named colors.
    var accentColor: Color {
        switch self {
        case .pi:            return .mdAccent
        case .math:          return .mdPink
        case .chemistry:     return .mdGreen
        case .geography:     return .mdAmber
        case .brainTraining: return .mdRed
        case .science:       return .mdAccent
        case .history:       return .mdAmber
        case .physics:       return .mdPink
        case .sport:         return .mdGreen
        case .grammar:       return .mdAccent
        }
    }

    /// Deep tinted background used as the card surface for this mode.
    var deepBg: Color {
        switch self {
        case .pi:            return Color(red: 0.067, green: 0.063, blue: 0.165)
        case .math:          return Color(red: 0.094, green: 0.039, blue: 0.071)
        case .chemistry:     return Color(red: 0.05,  green: 0.13,  blue: 0.09)
        case .geography:     return Color(red: 0.13,  green: 0.08,  blue: 0.03)
        case .brainTraining: return Color(red: 0.13,  green: 0.04,  blue: 0.05)
        case .science:       return Color(red: 0.04,  green: 0.10,  blue: 0.16)
        case .history:       return Color(red: 0.14,  green: 0.09,  blue: 0.04)
        case .physics:       return Color(red: 0.11,  green: 0.05,  blue: 0.10)
        case .sport:         return Color(red: 0.04,  green: 0.12,  blue: 0.07)
        case .grammar:       return Color(red: 0.05,  green: 0.10,  blue: 0.14)
        }
    }

    var localizedTitle: String {
        switch self {
        case .pi:            return String(localized: "mode_pi")
        case .math:          return String(localized: "mode_math")
        case .chemistry:     return String(localized: "mode_chemistry")
        case .geography:     return String(localized: "mode_geography")
        case .brainTraining: return String(localized: "mode_brain_training")
        case .science:       return String(localized: "mode_science")
        case .history:       return String(localized: "mode_history")
        case .physics:       return String(localized: "mode_physics")
        case .sport:         return String(localized: "mode_sport")
        case .grammar:       return String(localized: "mode_grammar")
        }
    }
}

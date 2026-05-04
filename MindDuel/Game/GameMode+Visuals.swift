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
    /// Darkened tint used as the surface of cards/pills for this mode.
    /// Pi & Math overrides match the design's #11102a / #180a12 so Pi (light
    /// indigo) and Math (hot pink) don't wash out on-device — the asset
    /// tokens (mdAccentDeep / mdPinkDeep) are too bright for that role.
    var deepBg: Color {
        switch self {
        case .pi:        return Color(red: 0.067, green: 0.063, blue: 0.165)  // #11102a
        case .math:      return Color(red: 0.094, green: 0.039, blue: 0.071)  // #180a12
        case .chemistry: return Color(red: 0.05,  green: 0.13,  blue: 0.09)   // dark green
        case .geography: return Color(red: 0.13,  green: 0.08,  blue: 0.03)   // dark amber
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

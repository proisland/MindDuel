import Foundation

enum GameMode: String, Identifiable, Codable, CaseIterable {
    case pi
    case math
    case chemistry
    case geography
    /// #116: brain-training puzzles (number-sequence pattern recognition,
    /// arithmetic shortcuts, working-memory drills). Same scoring/lives
    /// model as the existing modes.
    case brainTraining
    /// #98: natural science questions (biology, physics, astronomy, geology).
    case science
    /// #59: history questions (Norway + world, prehistory through modern era).
    case history
    /// #16: physics questions (mekanikk, elektrisitet, termodynamikk, m.m.).
    case physics
    /// #67: sport questions (populære idretter, regler, kjente utøvere, OL).
    case sport
    /// #39: grammar questions in the user's selected language.
    case grammar

    var id: String { rawValue }

    /// Backend slug for this mode (matches the `slug` column in the database).
    var slug: String {
        switch self {
        case .pi:            return "pi"
        case .math:          return "math"
        case .chemistry:     return "chem"
        case .geography:     return "geo"
        case .brainTraining: return "brain"
        case .science:       return "science"
        case .history:       return "history"
        case .physics:       return "physics"
        case .sport:         return "sport"
        case .grammar:       return "grammar"
        }
    }

    /// Reverse-lookup from backend slug.
    init?(slug: String) {
        switch slug {
        case "pi":      self = .pi
        case "math":    self = .math
        case "chem":    self = .chemistry
        case "geo":     self = .geography
        case "brain":   self = .brainTraining
        case "science": self = .science
        case "history": self = .history
        case "physics": self = .physics
        case "sport":   self = .sport
        case "grammar": self = .grammar
        default:        return nil
        }
    }

    /// Localization key for the human-readable mode name. Used by every view
    /// that lists modes so adding a new case auto-propagates everywhere (#52).
    var titleKey: String {
        switch self {
        case .pi:            return "mode_pi"
        case .math:          return "mode_math"
        case .chemistry:     return "mode_chemistry"
        case .geography:     return "mode_geography"
        case .brainTraining: return "mode_brain_training"
        case .science:       return "mode_science"
        case .history:       return "mode_history"
        case .physics:       return "mode_physics"
        case .sport:         return "mode_sport"
        case .grammar:       return "mode_grammar"
        }
    }
}

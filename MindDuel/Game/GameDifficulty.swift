import Foundation

enum GameDifficulty: String, CaseIterable {
    case easy   = "easy"
    case normal = "normal"
    case hard   = "hard"

    static let defaultsKey = "game.difficulty"

    static var stored: GameDifficulty {
        GameDifficulty(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .normal
    }

    var timerSeconds: Double {
        switch self {
        case .easy:   return 15.0
        case .normal: return 10.0
        case .hard:   return 5.0
        }
    }

    // Dividing avgTime by this multiplier gives equivalent effect to multiplying score
    var scoreMultiplier: Double {
        switch self {
        case .easy:   return 0.6
        case .normal: return 1.0
        case .hard:   return 1.5
        }
    }
}

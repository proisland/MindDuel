import Foundation

enum GameMode: Identifiable {
    case pi
    case math

    var id: String {
        switch self {
        case .pi: return "pi"
        case .math: return "math"
        }
    }
}

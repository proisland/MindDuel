import Foundation

enum GameMode: String, Identifiable, Codable {
    case pi
    case math

    var id: String { rawValue }
}

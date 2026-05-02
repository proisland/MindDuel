import Foundation

enum GameMode: String, Identifiable, Codable {
    case pi
    case math
    case chemistry

    var id: String { rawValue }
}

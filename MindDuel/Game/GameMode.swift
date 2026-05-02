import Foundation

enum GameMode: String, Identifiable, Codable {
    case pi
    case math
    case chemistry
    case geography

    var id: String { rawValue }
}

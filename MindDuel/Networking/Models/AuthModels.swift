import Foundation

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let isNew: Bool
}

struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String
}

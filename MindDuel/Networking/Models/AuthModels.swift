import Foundation

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let needsUsername: Bool
    let user: AuthUser

    struct AuthUser: Decodable {
        let id: String
    }
}

struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String
}

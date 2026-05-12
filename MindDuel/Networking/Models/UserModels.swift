import Foundation

struct APIUser: Decodable {
    let id: String
    let username: String?
    let avatarEmoji: String
    let isPremium: Bool
    let isSuspended: Bool
    let createdAt: Date
    let birthDate: Date?
    let dailyQuota: QuotaInfo?
    let progressions: [APIProgression]?
}

struct APIProgression: Decodable {
    let mode: String
    let position: Double
    let progress: Double
}

struct QuotaInfo: Decodable {
    let used: Int
    let limit: Int
}

struct UsernameResponse: Decodable {
    let id: String
    let username: String
    let avatarEmoji: String
}

struct PublicProfile: Decodable {
    let id: String
    let username: String
    let avatarEmoji: String
    let isPremium: Bool
    let progressions: [APIProgression]
}

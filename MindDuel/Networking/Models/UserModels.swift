import Foundation

struct APIUser: Decodable {
    let id: String
    let username: String?
    let avatarEmoji: String
    let isPremium: Bool
    let createdAt: Date
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
    let resetsAt: Date
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

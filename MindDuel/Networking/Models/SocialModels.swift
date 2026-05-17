import Foundation

struct APIFriend: Decodable {
    let id: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let isPremium: Bool
    let lastActiveAt: Date?
}

struct FriendsResponse: Decodable {
    let friends: [APIFriend]
}

struct FriendRequestsResponse: Decodable {
    let sent: [APIFriendRequest]
    let received: [APIFriendRequest]
}

struct APIFriendRequest: Decodable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let fromUsername: String?
    let toUsername: String?
    let fromAvatarEmoji: String?
    let createdAt: Date
}

struct ScoreboardEntry: Decodable {
    let rank: Int
    let userId: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let avgScore: Int
}

struct ScoreboardResponse: Decodable {
    let entries: [ScoreboardEntry]
}

struct UserSearchResult: Decodable, Identifiable {
    let id: String
    let username: String
    let avatarEmoji: String
    let avatarUrl: String?
    let isPremium: Bool
}

// MARK: – Social activity feed

struct SocialFeedUserSnippet: Codable {
    let username: String
    let avatarEmoji: String
}

enum SocialFeedItemType: String, Codable {
    case newFriend = "new_friend"
    case streak
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SocialFeedItemType(rawValue: raw) ?? .unknown
    }
}

struct SocialFeedItem: Identifiable, Codable {
    let id: String
    let type: SocialFeedItemType
    let createdAt: Date
    // new_friend
    let user1: SocialFeedUserSnippet?
    let user2: SocialFeedUserSnippet?
    let isMe: Bool?
    // streak
    let user: SocialFeedUserSnippet?
    let streakCount: Int?
    let modeName: String?
    let isMine: Bool?
}

struct SocialFeedResponse: Decodable {
    let feed: [SocialFeedItem]
}

struct RoomResponse: Decodable {
    let id: String
    let code: String
}

struct RoomInfo: Decodable {
    let id: String
    let code: String
    let mode: String
    let hostId: String
    let maxPlayers: Int
    let state: String
}

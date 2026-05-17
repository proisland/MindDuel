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

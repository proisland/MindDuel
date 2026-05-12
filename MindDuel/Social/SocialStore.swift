import SwiftUI
import UserNotifications

struct UserProfile: Identifiable {
    let id: String
    let username: String
    var avatarEmoji: String = "🎮"
    let piScore: Int
    let mathScore: Int
    var chemScore: Int = 0
    var geoScore: Int = 0
    var brainScore: Int = 0
    var scienceScore: Int = 0
    var historyScore: Int = 0
    var physicsScore: Int = 0
    var sportScore: Int = 0
    var grammarScore: Int = 0
    let piLevel: Int
    let mathLevel: Int
    var chemLevel: Int = 1
    var geoLevel: Int = 1
    var brainLevel: Int = 1
    var scienceLevel: Int = 1
    var historyLevel: Int = 1
    var physicsLevel: Int = 1
    var sportLevel: Int = 1
    var grammarLevel: Int = 1
    let roundsPlayed: Int
    let age: Int?
    let city: String?
    let memberSince: String
    let lastActive: String
    var isFriend: Bool
    var isFlagged: Bool
    var isPremium: Bool = false
    /// Average answer time in seconds (#57). 0 = unknown / no data.
    var avgAnswerTime: Double = 0

    var totalScore: Int { piScore + mathScore + chemScore + geoScore + brainScore + scienceScore + historyScore + physicsScore + sportScore + grammarScore }
    var initials: String { String(username.prefix(2)).uppercased() }

    func score(for mode: GameMode) -> Int {
        switch mode {
        case .pi:            return piScore
        case .math:          return mathScore
        case .chemistry:     return chemScore
        case .geography:     return geoScore
        case .brainTraining: return brainScore
        case .science:       return scienceScore
        case .history:       return historyScore
        case .physics:       return physicsScore
        case .sport:         return sportScore
        case .grammar:       return grammarScore
        }
    }

    func level(for mode: GameMode) -> Int {
        switch mode {
        case .pi:            return piLevel
        case .math:          return mathLevel
        case .chemistry:     return chemLevel
        case .geography:     return geoLevel
        case .brainTraining: return brainLevel
        case .science:       return scienceLevel
        case .history:       return historyLevel
        case .physics:       return physicsLevel
        case .sport:         return sportLevel
        case .grammar:       return grammarLevel
        }
    }

    var avatarColor: Color {
        let colors: [Color] = [.mdAccentDeep, .mdPinkDeep, .mdGreen, .mdAmber]
        return colors[abs(username.hashValue) % colors.count]
    }
}

// Convenience inits in extension to preserve the synthesized memberwise init.
extension UserProfile {
    init(from friend: APIFriend) {
        self.init(
            id: friend.id,
            username: friend.username,
            avatarEmoji: friend.avatarEmoji,
            piScore: 0, mathScore: 0, piLevel: 1, mathLevel: 1,
            roundsPlayed: 0, age: nil, city: nil,
            memberSince: "–",
            lastActive: friend.lastActiveAt.map { Self.relativeTime($0) } ?? "–",
            isFriend: true, isFlagged: false, isPremium: friend.isPremium
        )
    }

    init(from request: APIFriendRequest) {
        self.init(
            id: request.fromUserId,
            username: request.fromUsername ?? "–",
            avatarEmoji: request.fromAvatarEmoji ?? "🎮",
            piScore: 0, mathScore: 0, piLevel: 1, mathLevel: 1,
            roundsPlayed: 0, age: nil, city: nil,
            memberSince: "–", lastActive: "–",
            isFriend: false, isFlagged: false
        )
    }

    private static func relativeTime(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "Nå" }
        if secs < 3600 { return "\(secs/60)m siden" }
        if secs < 86400 { return "\(secs/3600)t siden" }
        return "\(secs/86400)d siden"
    }
}

@MainActor final class SocialStore: ObservableObject {
    static let shared = SocialStore()

    // Live data from API (empty until refreshed)
    @Published private(set) var apiFriends: [APIFriend] = []
    @Published private(set) var apiPendingRequests: [APIFriendRequest] = []

    // Legacy local state kept for UI compatibility
    @Published private(set) var friendUsernames: Set<String> = []
    @Published private(set) var sentRequestUsernames: Set<String> = []
    @Published private(set) var pendingRequests: [UserProfile] = []

    private init() {}

    // MARK: – Refresh from API

    func refresh() async {
        async let friendsTask: [APIFriend] = (try? APIClient.shared.get("friends")) ?? []
        async let requestsTask: FriendRequestsResponse? = try? APIClient.shared.get("friends/requests")
        let (friends, requestsResp) = await (friendsTask, requestsTask)

        apiFriends = friends
        friendUsernames = Set(friends.map(\.username))
        if let reqs = requestsResp {
            apiPendingRequests = reqs.received
            sentRequestUsernames = Set(reqs.sent.compactMap(\.toUsername))
            pendingRequests = reqs.received.map { UserProfile(from: $0) }
        }
    }

    // MARK: – Queries

    var friends: [UserProfile] {
        apiFriends.map { UserProfile(from: $0) }
    }

    var friendsLeaderboard: [UserProfile] {
        friends.sorted { $0.totalScore > $1.totalScore }
    }

    var globalLeaderboard: [UserProfile] { [] } // loaded on-demand via ScoreboardView

    func profile(for username: String) -> UserProfile? {
        apiFriends.first { $0.username == username }.map { UserProfile(from: $0) }
    }

    var totalPendingCount: Int { pendingRequests.count }

    // MARK: – Actions

    func sendFriendRequest(to username: String) {
        sentRequestUsernames.insert(username)
        Task {
            do {
                struct Body: Encodable { let username: String }
                let _: Empty = try await APIClient.shared.post("friends/requests", body: Body(username: username))
            } catch {
                sentRequestUsernames.remove(username)
            }
        }
    }

    func acceptRequest(from username: String) {
        guard let req = apiPendingRequests.first(where: { $0.fromUsername == username }) else { return }
        apiPendingRequests.removeAll { $0.id == req.id }
        pendingRequests.removeAll { $0.username == username }
        Task {
            do {
                struct Body: Encodable { let requestId: String; let accept: Bool }
                let _: Empty = try await APIClient.shared.post(
                    "friends/requests/respond",
                    body: Body(requestId: req.id, accept: true)
                )
                await refresh()
            } catch {
                await refresh() // restore correct state on error
            }
        }
    }

    func declineRequest(from username: String) {
        guard let req = apiPendingRequests.first(where: { $0.fromUsername == username }) else { return }
        apiPendingRequests.removeAll { $0.id == req.id }
        pendingRequests.removeAll { $0.username == username }
        Task {
            do {
                struct Body: Encodable { let requestId: String; let accept: Bool }
                let _: Empty = try await APIClient.shared.post(
                    "friends/requests/respond",
                    body: Body(requestId: req.id, accept: false)
                )
            } catch {
                await refresh()
            }
        }
    }

    func removeFriend(username: String) {
        guard let friend = apiFriends.first(where: { $0.username == username }) else { return }
        apiFriends.removeAll { $0.id == friend.id }
        friendUsernames.remove(username)
        Task {
            try? await APIClient.shared.delete("friends/\(friend.id)")
        }
    }

    // MARK: – No-op stubs kept for call-site compatibility

    func seedMockRequestIfNeeded() {}

    /// Schedule a local notification when a new friend request arrives (#105).
    func notifyIncomingFriendRequest(from username: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification_friend_request_title")
            content.body  = String(format: String(localized: "notification_friend_request_body"),
                                   username)
            content.sound = .default
            content.userInfo = ["kind": "friendRequest", "username": username]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: "friendRequest-\(username)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func simulateIncomingRequest() { Task { await refresh() } }

    func resetForTesting() {
        apiFriends = []
        apiPendingRequests = []
        friendUsernames = []
        sentRequestUsernames = []
        pendingRequests = []
    }
}

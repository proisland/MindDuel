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
    var avatarUrl: String? = nil
    /// Average answer time in seconds (#57). 0 = unknown / no data.
    var avgAnswerTime: Double = 0
    /// Score from the scoreboard API (avgScore). Used for server-only modes
    /// where scores aren't stored locally in ProgressionStore.
    var apiScore: Int = 0

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
            isFriend: true, isFlagged: false, isPremium: friend.isPremium,
            avatarUrl: friend.avatarUrl
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
            isFriend: false, isFlagged: false,
            avatarUrl: request.fromAvatarUrl
        )
    }

    /// Minimal stub for navigating to OtherProfileView when only a username is known.
    /// OtherProfileView loads the real data from the network on appear.
    static func stub(username: String) -> UserProfile {
        UserProfile(
            id: username,
            username: username,
            piScore: 0, mathScore: 0, piLevel: 1, mathLevel: 1,
            roundsPlayed: 0, age: nil, city: nil,
            memberSince: "–", lastActive: "–",
            isFriend: false, isFlagged: false
        )
    }

    static func relativeTime(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "nb_NO")
        timeFmt.dateFormat = "HH:mm"
        let timeStr = timeFmt.string(from: date)
        if cal.isDateInToday(date)     { return "I dag kl. \(timeStr)" }
        if cal.isDateInYesterday(date) { return "I går kl. \(timeStr)" }
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "nb_NO")
        dateFmt.dateFormat = "d. MMM"
        return "\(dateFmt.string(from: date)) kl. \(timeStr)"
    }
}

@MainActor final class SocialStore: ObservableObject {
    static let shared = SocialStore()

    // Live data from API (empty until refreshed)
    @Published private(set) var apiFriends: [APIFriend] = []
    @Published private(set) var apiPendingRequests: [APIFriendRequest] = []
    @Published private(set) var apiSentRequests: [APIFriendRequest] = []
    @Published private(set) var socialFeed: [SocialFeedItem] = []
    @Published private(set) var friendSuggestions: [FriendSuggestion] = []

    // Legacy local state kept for UI compatibility
    @Published private(set) var friendUsernames: Set<String> = []
    @Published private(set) var sentRequestUsernames: Set<String> = []
    @Published private(set) var pendingRequests: [UserProfile] = []
    @Published private(set) var friends: [UserProfile] = []

    /// Set to true from AppDelegate when user taps a friendRequest push notification.
    /// HomeView consumes this by opening ProfileView, then resets it to false.
    @Published var shouldOpenFriendRequests: Bool = false

    private init() {}

    // MARK: – Refresh from API

    func refresh() async {
        async let friendsTask: FriendsResponse? = try? APIClient.shared.get("friends")
        async let requestsTask: FriendRequestsResponse? = try? APIClient.shared.get("friends/requests")
        async let feedTask: SocialFeedResponse? = try? APIClient.shared.get("activity/feed")
        async let suggestionsTask: FriendSuggestionsResponse? = try? APIClient.shared.get("friends/suggestions")
        let (friendsResp, requestsResp, feedResp, suggestionsResp) = await (friendsTask, requestsTask, feedTask, suggestionsTask)

        let fetchedFriends = friendsResp?.friends ?? []
        apiFriends = fetchedFriends
        friends = fetchedFriends.map { UserProfile(from: $0) }
        friendUsernames = Set(fetchedFriends.map(\.username))
        if let reqs = requestsResp {
            apiPendingRequests = reqs.received
            apiSentRequests = reqs.sent
            sentRequestUsernames = Set(reqs.sent.compactMap(\.toUsername))
            pendingRequests = reqs.received.map { UserProfile(from: $0) }
        }
        socialFeed = feedResp?.feed ?? []
        friendSuggestions = suggestionsResp?.suggestions ?? []
    }

    // MARK: – Queries

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
                struct RequestResponse: Decodable { let friendshipCreated: Bool?; let message: String? }
                let resp: RequestResponse = try await APIClient.shared.post("friends/requests", body: Body(username: username))
                if resp.friendshipCreated == true {
                    sentRequestUsernames.remove(username)
                    await refresh()
                }
            } catch APIError.conflict {
                // 409 means a request already exists — keep the optimistic UI state
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

    func withdrawRequest(to username: String) {
        guard let req = apiSentRequests.first(where: { $0.toUsername == username }) else { return }
        apiSentRequests.removeAll { $0.id == req.id }
        sentRequestUsernames.remove(username)
        Task {
            try? await APIClient.shared.delete("friends/requests/\(req.id)")
        }
    }

    func removeFriend(username: String) {
        guard let friend = apiFriends.first(where: { $0.username == username }) else { return }
        apiFriends.removeAll { $0.id == friend.id }
        friends.removeAll { $0.id == friend.id }
        friendUsernames.remove(username)
        Task {
            try? await APIClient.shared.delete("friends/\(friend.id)")
        }
    }

    // MARK: – No-op stubs kept for call-site compatibility

    func seedMockRequestIfNeeded() {}

    func simulateIncomingRequest() { Task { await refresh() } }

    func resetForTesting() {
        apiFriends = []
        apiPendingRequests = []
        apiSentRequests = []
        friendUsernames = []
        sentRequestUsernames = []
        pendingRequests = []
        friends = []
    }
}

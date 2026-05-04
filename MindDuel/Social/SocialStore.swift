import SwiftUI
import UserNotifications

struct UserProfile: Identifiable {
    let id: String
    let username: String
    let piScore: Int
    let mathScore: Int
    var chemScore: Int = 0
    var geoScore: Int = 0
    let piLevel: Int
    let mathLevel: Int
    var chemLevel: Int = 1
    var geoLevel: Int = 1
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

    var totalScore: Int { piScore + mathScore + chemScore + geoScore }
    var initials: String { String(username.prefix(2)).uppercased() }

    func score(for mode: GameMode) -> Int {
        switch mode {
        case .pi:        return piScore
        case .math:      return mathScore
        case .chemistry: return chemScore
        case .geography: return geoScore
        }
    }

    func level(for mode: GameMode) -> Int {
        switch mode {
        case .pi:        return piLevel
        case .math:      return mathLevel
        case .chemistry: return chemLevel
        case .geography: return geoLevel
        }
    }

    var avatarColor: Color {
        let colors: [Color] = [.mdAccentDeep, .mdPinkDeep, .mdGreen, .mdAmber]
        return colors[abs(username.hashValue) % colors.count]
    }
}

@MainActor final class SocialStore: ObservableObject {
    static let shared = SocialStore()

    private static let mockUsers: [UserProfile] = [
        UserProfile(id: "u1", username: "magnus",  piScore: 3200, mathScore: 2100, piLevel: 14, mathLevel: 7,  roundsPlayed: 203, age: 28, city: "Oslo",      memberSince: "januar 2025", lastActive: "Nå",       isFriend: false, isFlagged: false),
        UserProfile(id: "u2", username: "sara",    piScore: 1800, mathScore: 2800, piLevel:  9, mathLevel: 9,  roundsPlayed: 156, age: 24, city: "Bergen",    memberSince: "februar 2025", lastActive: "3t siden", isFriend: false, isFlagged: false),
        UserProfile(id: "u3", username: "alex",    piScore: 2400, mathScore: 1900, piLevel: 11, mathLevel: 6,  roundsPlayed:  87, age: 31, city: "Stavanger", memberSince: "mars 2025",    lastActive: "1d siden", isFriend: false, isFlagged: false),
        UserProfile(id: "u4", username: "luna",    piScore:  900, mathScore: 1100, piLevel:  5, mathLevel: 4,  roundsPlayed:  42, age: 19, city: "Trondheim", memberSince: "april 2025",   lastActive: "5t siden", isFriend: false, isFlagged: false),
        UserProfile(id: "u5", username: "kai",     piScore: 9800, mathScore: 7200, piLevel: 20, mathLevel: 10, roundsPlayed:  12, age: nil, city: nil,        memberSince: "april 2025",   lastActive: "2t siden", isFriend: false, isFlagged: true),
    ]

    @Published private(set) var friendUsernames: Set<String>
    @Published private(set) var sentRequestUsernames: Set<String>
    @Published private(set) var pendingRequests: [UserProfile]

    private init() {
        let d = UserDefaults.standard
        friendUsernames      = Set(d.stringArray(forKey: "friendUsernames") ?? [])
        sentRequestUsernames = Set(d.stringArray(forKey: "sentRequestUsernames") ?? [])
        let pendingNames     = d.stringArray(forKey: "pendingRequestUsernames") ?? []
        pendingRequests      = pendingNames.compactMap { n in SocialStore.mockUsers.first { $0.username == n } }

        // Seed one mock incoming request on first launch so the feature is testable
        if !d.bool(forKey: "didSeedMockRequest") {
            d.set(true, forKey: "didSeedMockRequest")
            if let magnus = SocialStore.mockUsers.first(where: { $0.username == "magnus" }),
               !friendUsernames.contains("magnus") {
                pendingRequests = [magnus]
                d.set(["magnus"], forKey: "pendingRequestUsernames")
            }
        }
    }

    // MARK: – Queries

    var friends: [UserProfile] {
        Self.mockUsers.filter { friendUsernames.contains($0.username) }
    }

    var friendsLeaderboard: [UserProfile] {
        friends.sorted { $0.totalScore > $1.totalScore }
    }

    var globalLeaderboard: [UserProfile] {
        Self.mockUsers.sorted { $0.totalScore > $1.totalScore }
    }

    func profile(for username: String) -> UserProfile? {
        Self.mockUsers.first { $0.username == username }
    }

    var totalPendingCount: Int { pendingRequests.count }

    // MARK: – Actions

    func sendFriendRequest(to username: String) {
        sentRequestUsernames.insert(username)
        UserDefaults.standard.set(Array(sentRequestUsernames), forKey: "sentRequestUsernames")
    }

    func acceptRequest(from username: String) {
        pendingRequests.removeAll { $0.username == username }
        savePending()
        friendUsernames.insert(username)
        UserDefaults.standard.set(Array(friendUsernames), forKey: "friendUsernames")
    }

    func declineRequest(from username: String) {
        pendingRequests.removeAll { $0.username == username }
        savePending()
    }

    func removeFriend(username: String) {
        friendUsernames.remove(username)
        UserDefaults.standard.set(Array(friendUsernames), forKey: "friendUsernames")
    }

    // MARK: – Mock seeding (called once after first round)

    func seedMockRequestIfNeeded() {
        let key = "didSeedMockRequest"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        if let magnus = Self.mockUsers.first(where: { $0.username == "magnus" }) {
            pendingRequests = [magnus]
            savePending()
            notifyIncomingFriendRequest(from: magnus.username)
        }
    }

    /// Schedule a local notification when a new friend request arrives (#105).
    /// Fires immediately so iOS surfaces it whether the app is foreground or
    /// locked. Tapping the notification deep-links to the profile screen via
    /// the userInfo payload (handled in App/RootView when wired up).
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

    /// Test hook used by the debug section to simulate an inbound request
    /// without restarting the app.
    func simulateIncomingRequest() {
        let candidates = Self.mockUsers.filter { user in
            !friendUsernames.contains(user.username) &&
            !pendingRequests.contains(where: { $0.username == user.username })
        }
        guard let user = candidates.first else { return }
        pendingRequests.append(user)
        savePending()
        notifyIncomingFriendRequest(from: user.username)
    }

    private func savePending() {
        UserDefaults.standard.set(pendingRequests.map(\.username), forKey: "pendingRequestUsernames")
    }

    func resetForTesting() {
        let d = UserDefaults.standard
        friendUsernames = []
        sentRequestUsernames = []
        d.set([String](), forKey: "friendUsernames")
        d.set([String](), forKey: "sentRequestUsernames")
        d.set(false, forKey: "didSeedMockRequest")
        if let magnus = Self.mockUsers.first(where: { $0.username == "magnus" }) {
            pendingRequests = [magnus]
            d.set(["magnus"], forKey: "pendingRequestUsernames")
            d.set(true, forKey: "didSeedMockRequest")
        }
    }
}

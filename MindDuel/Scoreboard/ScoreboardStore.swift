import Foundation

@MainActor
final class ScoreboardStore: ObservableObject {
    static let shared = ScoreboardStore()

    @Published private(set) var globalEntries: [ScoreboardEntry] = []
    @Published private(set) var friendEntries: [ScoreboardEntry] = []
    @Published private(set) var weeklyFriendsResponse: WeeklyLeaderboardResponse? = nil
    @Published private(set) var isLoading = false

    private var lastMode: String?

    private init() {}

    func refresh(slug: String?) async {
        let key = slug ?? "total"
        guard key != lastMode || globalEntries.isEmpty else { return }
        isLoading = true
        lastMode = key
        let query = slug.map { ["mode": $0] } ?? [:]
        async let globalTask: ScoreboardResponse? = try? APIClient.shared.get(
            "scoreboard/global", query: query
        )
        async let friendTask: ScoreboardResponse? = try? APIClient.shared.get(
            "scoreboard/friends", query: query
        )
        async let weeklyTask: WeeklyLeaderboardResponse? = try? APIClient.shared.get(
            "scoreboard/weekly-friends", query: query
        )
        let (g, f, w) = await (globalTask, friendTask, weeklyTask)
        globalEntries = g?.entries ?? []
        friendEntries = f?.entries ?? []
        weeklyFriendsResponse = w
        isLoading = false
    }

    func userProfile(for entry: ScoreboardEntry) -> UserProfile {
        var profile = UserProfile(
            id: entry.userId,
            username: entry.username,
            avatarEmoji: entry.avatarEmoji,
            piScore: 0, mathScore: 0, piLevel: 1, mathLevel: 1,
            roundsPlayed: 0, age: nil, city: nil,
            memberSince: "–", lastActive: "–",
            isFriend: SocialStore.shared.friendUsernames.contains(entry.username),
            isFlagged: false,
            avatarUrl: entry.avatarUrl
        )
        profile.apiScore = entry.avgScore
        return profile
    }
}

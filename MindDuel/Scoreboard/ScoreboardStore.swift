import Foundation

@MainActor
final class ScoreboardStore: ObservableObject {
    static let shared = ScoreboardStore()

    @Published private(set) var globalEntries: [ScoreboardEntry] = []
    @Published private(set) var friendEntries: [ScoreboardEntry] = []
    @Published private(set) var isLoading = false

    private var lastMode: String?

    private init() {}

    func refresh(mode: GameMode) async {
        guard mode.slug != lastMode || globalEntries.isEmpty else { return }
        isLoading = true
        lastMode = mode.slug
        async let globalTask: [ScoreboardEntry] = (try? APIClient.shared.get(
            "scoreboard/global", query: ["mode": mode.slug]
        )) ?? []
        async let friendTask: [ScoreboardEntry] = (try? APIClient.shared.get(
            "scoreboard/friends", query: ["mode": mode.slug]
        )) ?? []
        (globalEntries, friendEntries) = await (globalTask, friendTask)
        isLoading = false
    }

    func userProfile(for entry: ScoreboardEntry) -> UserProfile {
        UserProfile(
            id: entry.userId,
            username: entry.username,
            avatarEmoji: entry.avatarEmoji,
            piScore: 0, mathScore: 0, piLevel: 1, mathLevel: 1,
            roundsPlayed: 0, age: nil, city: nil,
            memberSince: "–", lastActive: "–",
            isFriend: SocialStore.shared.friendUsernames.contains(entry.username),
            isFlagged: false
        )
    }
}

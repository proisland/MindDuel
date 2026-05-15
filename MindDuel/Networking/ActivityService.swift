import Foundation

/// Client for activity-related endpoints (kudos, duel streaks).
enum ActivityService {

    static func sendKudos(roomId: String) async throws {
        struct Empty: Decodable {}
        _ = try? await APIClient.shared.post("activity/\(roomId)/kudos", body: EmptyBody()) as Empty
    }

    static func fetchDuelStreaks() async throws -> [DuelStreakEntry] {
        struct Response: Decodable { let streaks: [DuelStreakEntry] }
        let response: Response = try await APIClient.shared.get("activity/duel-streaks")
        return response.streaks
    }
}

struct EmptyBody: Encodable {}

struct DuelStreakEntry: Decodable, Identifiable {
    var id: String { opponentId }
    let opponentId: String
    let opponentUsername: String
    let opponentAvatarEmoji: String
    let streak: Int
}

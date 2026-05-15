import Foundation
import SwiftUI

struct GameSessionResponse: Decodable {
    let sessionToken: String
    let mode: String
    let isTraining: Bool
    let startPosition: Int
    let quotaRemaining: Int
}

struct AnswerRequest: Encodable {
    let questionRef: String
    let userAnswer: String
    let answerTimeMs: Int
    let waitTimeMs: Int
    let wasSkipped: Bool
    let isCorrect: Bool?
}

struct AnswerResponse: Decodable {
    let isCorrect: Bool
    let correctAnswer: String
    let quotaRemaining: Int
}

struct EndSessionRequest: Encodable {
    let reason: String
}

struct EndSessionResponse: Decodable {
    let score: Double
    let progression: ProgressionDelta
}

struct ProgressionDelta: Decodable {
    let mode: String
    let position: Double
    let progress: Double
    let currentStreak: Int?
    let longestStreak: Int?
}

struct DailyChallenge: Decodable {
    struct ModeInfo: Decodable {
        let slug: String
        let nameNo: String
        let nameEn: String
        let iconSymbol: String
        let colorHex: String
    }
    let date: String
    let mode: ModeInfo
}

struct KudosUnread: Decodable {
    let count: Int
}

struct WeeklyLeaderboardEntry: Decodable, Identifiable {
    var id: String { userId }
    let rank: Int
    let userId: String
    let username: String
    let avatarEmoji: String
    let avgScore: Int
    let roundCount: Int
    let isMe: Bool
}

struct WeeklyLeaderboardResponse: Decodable {
    let mode: String
    let entries: [WeeklyLeaderboardEntry]
    let friendCount: Int
    let minFriends: Int
}

struct QuotaSyncRequest: Encodable {
    let localDate: String
    let localCount: Int
}

struct ModeResponse: Codable {
    let id: String
    let name: String
    let slug: String
    let isActive: Bool
    let startsAt: Date?
    let endsAt: Date?
}

struct QuestionVersionInfo: Decodable {
    let version: Int
    let language: String
}

struct QuestionVersionsResponse: Decodable {
    let versions: [String: QuestionVersionInfo]
}

struct QuestionPackResponse: Decodable {
    let mode: String
    let language: String
    let version: Int
    let questions: [APIQuestion]
}

struct APIQuestion: Codable {
    let id: String
    let prompt: String
    let options: [String]
    let answer: String
    let level: Int

    func shufflingOptions() -> APIQuestion {
        APIQuestion(id: id, prompt: prompt, options: options.shuffled(), answer: answer, level: level)
    }
}

/// A game mode as returned by `GET /v1/modes`. Modes whose `slug` does not
/// match a `GameMode` enum case are "server-only" — shown in the UI using
/// `iconSymbol` and `colorHex` from the server.
struct ServerMode: Codable, Identifiable, Equatable, Hashable {
    // New bilingual fields (backend v2+)
    let nameNo: String?
    let nameEn: String?
    // Legacy single-language field (old backend)
    private let legacyName: String?

    let slug: String
    let iconSymbol: String
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case slug, nameNo, nameEn, iconSymbol, colorHex
        case legacyName = "name"
    }

    var id: String { slug }

    /// Picks the Norwegian or English name based on the device's preferred language,
    /// falling back to the legacy `name` field for old backend responses.
    var name: String {
        if let no = nameNo, let en = nameEn {
            let lang = Bundle.main.preferredLocalizations.first ?? "no"
            if lang.hasPrefix("en") && !en.isEmpty { return en }
            return no.isEmpty ? en : no
        }
        return legacyName ?? ""
    }

    var accentColor: Color {
        Color(hex: colorHex) ?? .mdAccent
    }

    var gameMode: GameMode? { GameMode(slug: slug) }
}

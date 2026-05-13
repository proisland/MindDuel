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
}

/// A game mode as returned by `GET /v1/modes`. Modes whose `slug` does not
/// match a `GameMode` enum case are "server-only" — shown in the UI using
/// `iconSymbol` and `colorHex` from the server.
struct ServerMode: Codable, Identifiable, Equatable {
    let slug: String
    let name: String
    let iconSymbol: String
    let colorHex: String

    var id: String { slug }

    var accentColor: Color {
        Color(hex: colorHex) ?? .mdAccent
    }

    var gameMode: GameMode? { GameMode(slug: slug) }
}

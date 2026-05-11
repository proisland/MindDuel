import Foundation

struct GameSessionResponse: Decodable {
    let token: String
    let mode: String
    let startsAt: Date
}

struct AnswerRequest: Encodable {
    let answeredAt: String // ISO8601 ms precision
    let answer: String
    let questionId: String
}

struct AnswerResponse: Decodable {
    let ok: Bool
    let correct: Bool
    let correctAnswer: String?
}

struct EndSessionRequest: Encodable {
    let endedAt: String
}

struct EndSessionResponse: Decodable {
    let score: Double
    let progression: ProgressionDelta
}

struct ProgressionDelta: Decodable {
    let position: Double
    let progress: Double
    let didLevelUp: Bool
}

struct QuotaSyncRequest: Encodable {
    let localUsed: Int
}

struct ModeResponse: Codable {
    let id: String
    let name: String
    let slug: String
    let isActive: Bool
    let startsAt: Date?
    let endsAt: Date?
}

struct QuestionVersionsResponse: Decodable {
    let versions: [String: Int]
}

struct QuestionPackResponse: Decodable {
    let mode: String
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

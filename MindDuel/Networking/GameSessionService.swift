import Foundation

/// Manages a single server-side game session lifecycle:
/// start → submit answers → end. All timing is recorded server-side.
actor GameSessionService {

    private var sessionToken: String?
    private var sessionStarted: Date?

    // MARK: – Lifecycle

    func startSession(mode: String) async throws -> String {
        struct Body: Encodable { let mode: String }
        let response: GameSessionResponse = try await APIClient.shared.post(
            "games/sessions",
            body: Body(mode: mode)
        )
        sessionToken = response.token
        sessionStarted = Date()
        return response.token
    }

    func submitAnswer(answeredAt: String, questionId: String, answer: String) async throws -> AnswerResponse {
        guard let token = sessionToken else { throw SessionError.noActiveSession }
        let body = AnswerRequest(answeredAt: answeredAt, answer: answer, questionId: questionId)
        return try await APIClient.shared.post("games/sessions/\(token)/answers", body: body)
    }

    func endSession() async throws -> EndSessionResponse {
        guard let token = sessionToken else { throw SessionError.noActiveSession }
        let body = EndSessionRequest(endedAt: ISO8601DateFormatter.ms.string(from: Date()))
        let result: EndSessionResponse = try await APIClient.shared.post(
            "games/sessions/\(token)/end",
            body: body
        )
        sessionToken = nil
        sessionStarted = nil
        return result
    }

    func syncQuota(localUsed: Int) async throws -> QuotaInfo {
        let body = QuotaSyncRequest(localUsed: localUsed)
        return try await APIClient.shared.post("games/quota/sync", body: body)
    }
}

enum SessionError: Error {
    case noActiveSession
}

extension ISO8601DateFormatter {
    static let ms: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

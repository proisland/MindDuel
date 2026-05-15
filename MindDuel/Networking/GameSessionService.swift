import Foundation

/// Manages a single server-side game session lifecycle:
/// start → submit answers → end.
///
/// Must be held by the view with `@StateObject` so SwiftUI preserves the
/// instance (and its `sessionToken`) across body re-evaluations. A plain
/// `private let` would re-init on every render, losing the token before
/// `endSession` is called.
@MainActor
final class GameSessionService: ObservableObject {

    private var sessionToken: String?
    private var sessionStarted: Date?
    private var lastEventAt: Date?

    // MARK: – Lifecycle

    func startSession(mode: String, startPosition: Int? = nil) async throws -> String {
        struct Body: Encodable {
            let mode: String
            let isTraining: Bool
            let localDate: String
            let startPosition: Int?
        }
        let localDate = DateFormatter.localDate.string(from: Date())
        do {
            let response: GameSessionResponse = try await APIClient.shared.post(
                "games/sessions",
                body: Body(mode: mode, isTraining: false, localDate: localDate, startPosition: startPosition)
            )
            sessionToken = response.sessionToken
            sessionStarted = Date()
            lastEventAt = Date()
            return response.sessionToken
        } catch APIError.forbidden {
            NotificationCenter.default.post(name: .accountSuspended, object: nil)
            throw APIError.forbidden
        }
    }

    func submitAnswer(
        answeredAt: String,
        questionId: String,
        answer: String,
        isCorrect: Bool? = nil
    ) async throws -> AnswerResponse {
        guard let token = sessionToken else { throw SessionError.noActiveSession }
        let now = Date()
        let answerTimeMs = max(200, Int((now.timeIntervalSince(lastEventAt ?? now)) * 1000))
        lastEventAt = now
        let body = AnswerRequest(
            questionRef: questionId,
            userAnswer: answer,
            answerTimeMs: answerTimeMs,
            waitTimeMs: 0,
            wasSkipped: false,
            isCorrect: isCorrect
        )
        return try await APIClient.shared.post("games/sessions/\(token)/answers", body: body)
    }

    func endSession(reason: String = "user_quit") async throws -> EndSessionResponse {
        guard let token = sessionToken else { throw SessionError.noActiveSession }
        let body = EndSessionRequest(reason: reason)
        let result: EndSessionResponse = try await APIClient.shared.post(
            "games/sessions/\(token)/end",
            body: body
        )
        sessionToken = nil
        sessionStarted = nil
        lastEventAt = nil
        // Propagate streak data from server to ProgressionStore
        if let current = result.progression.currentStreak,
           let longest = result.progression.longestStreak {
            await MainActor.run {
                ProgressionStore.shared.applyStreakUpdate(
                    mode: result.progression.mode,
                    currentStreak: current,
                    longestStreak: longest
                )
            }
        }
        return result
    }

    func syncQuota(localUsed: Int) async throws -> QuotaInfo {
        struct Body: Encodable { let localDate: String; let localCount: Int }
        let body = Body(localDate: DateFormatter.localDate.string(from: Date()), localCount: localUsed)
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

extension DateFormatter {
    static let localDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

extension Notification.Name {
    static let accountSuspended = Notification.Name("md.accountSuspended")
}

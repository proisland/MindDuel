import Foundation

/// Connects to a multiplayer room WebSocket. Sends and receives strongly-typed
/// game messages. The token is passed as a query param because iOS WebSocket
/// APIs don't support custom headers.
@MainActor
final class WebSocketClient: NSObject, ObservableObject {

    enum State {
        case disconnected, connecting, connected
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var lastMessage: WSMessage?

    private var task: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?

    #if DEBUG
    private var wsBase: String { AppEnvironment.current.wsBase }
    #else
    private let wsBase = "wss://api.mindduel.no/v1/ws/rooms"
    #endif

    func connect(roomId: String) {
        pingTask?.cancel()
        state = .connecting
        Task { @MainActor in
            await connectAsync(roomId: roomId)
        }
    }

    private func connectAsync(roomId: String) async {
        struct TicketResponse: Decodable { let ticket: String }
        guard let response = try? await APIClient.shared.post("rooms/ws/ticket", body: Empty()) as TicketResponse,
              var components = URLComponents(string: "\(wsBase)/\(roomId)/ws") else {
            state = .disconnected; return
        }
        components.queryItems = [URLQueryItem(name: "ticket", value: response.ticket)]
        guard let url = components.url else { state = .disconnected; return }

        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        scheduleReceive()
        schedulePing()
    }

    func disconnect() {
        pingTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    func send(_ message: WSClientMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    // MARK: – Receive loop

    private func scheduleReceive() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    if self.state != .connected { self.state = .connected }
                    self.handleRaw(msg)
                    self.scheduleReceive()
                case .failure:
                    self.state = .disconnected
                }
            }
        }
    }

    private func handleRaw(_ msg: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = msg,
              let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(WSMessage.self, from: data)
        else { return }
        lastMessage = parsed
    }

    private func schedulePing() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000) // 20 s
                task?.sendPing { _ in }
            }
        }
    }
}

// MARK: – Message types

enum WSMessage: Decodable {
    case joined(roomId: String, players: [WSPlayer])
    case playerLeft(userId: String)
    case roundStarted(roundIndex: Int, problem: WSProblem)
    case answerResult(userId: String, correct: Bool, score: Double)
    case roundEnded(scores: [WSScore])
    case gameEnded(finalScores: [WSScore])
    case error(message: String)

    private enum CodingKeys: String, CodingKey { case type, payload }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let p = try c.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        switch type {
        case "joined":
            self = .joined(
                roomId: try p.decode(String.self, forKey: .roomId),
                players: try p.decode([WSPlayer].self, forKey: .players)
            )
        case "playerLeft":
            self = .playerLeft(userId: try p.decode(String.self, forKey: .userId))
        case "roundStarted":
            self = .roundStarted(
                roundIndex: try p.decode(Int.self, forKey: .roundIndex),
                problem: try p.decode(WSProblem.self, forKey: .problem)
            )
        case "answerResult":
            self = .answerResult(
                userId: try p.decode(String.self, forKey: .userId),
                correct: try p.decode(Bool.self, forKey: .correct),
                score: try p.decode(Double.self, forKey: .score)
            )
        case "roundEnded":
            self = .roundEnded(scores: try p.decode([WSScore].self, forKey: .scores))
        case "gameEnded":
            self = .gameEnded(finalScores: try p.decode([WSScore].self, forKey: .finalScores))
        case "error":
            self = .error(message: try p.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown WS message type: \(type)")
        }
    }

    private enum PayloadKeys: String, CodingKey {
        case roomId, players, userId, roundIndex, problem, correct, score, scores, finalScores, message
    }
}

enum WSClientMessage: Encodable {
    case submitAnswer(questionId: String, answer: String, answeredAt: String)
    case ready

    private enum CodingKeys: String, CodingKey { case type, payload }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .submitAnswer(let qid, let ans, let at):
            try c.encode("submitAnswer", forKey: .type)
            var p = c.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
            try p.encode(qid, forKey: .questionId)
            try p.encode(ans, forKey: .answer)
            try p.encode(at, forKey: .answeredAt)
        case .ready:
            try c.encode("ready", forKey: .type)
        }
    }

    private enum PayloadKeys: String, CodingKey { case questionId, answer, answeredAt }
}

struct WSPlayer: Decodable {
    let userId: String
    let username: String
    let avatarEmoji: String
}

struct WSProblem: Decodable {
    let id: String
    let prompt: String
    let options: [String]?
    let timeoutSeconds: Int
}

struct WSScore: Decodable {
    let userId: String
    let username: String
    let score: Double
}

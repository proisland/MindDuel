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
    private let wsBase = "wss://mindduel-production-1180.up.railway.app/v1/ws/rooms"
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

// MARK: – Server → Client message types

/// Participant as sent in WS messages (matches backend Participant interface).
struct WSParticipant: Decodable {
    let userId: String
    let username: String
    let avatarEmoji: String?
    let avatarUrl: String?
    let lives: Int
    let skips: Int
    let isActive: Bool
    let score: Int
}

/// Full room state as sent in room_state / game_started messages.
struct WSRoomState: Decodable {
    let id: String
    let code: String
    let mode: String
    let startLevel: Int
    let hostUserId: String
    let participants: [WSParticipant]
    let turnIndex: Int
    let status: String
    let name: String?
    let questionsPerRound: Int?
    let currentRoundIndex: Int?
}

/// Scores entry in round_summary.
struct WSRoundScore: Decodable {
    let userId: String
    let username: String
    let score: Int
}

enum WSMessage: Decodable {
    case roomState(WSRoomState)
    case playerJoined(userId: String, participants: [WSParticipant])
    case gameStarted(WSRoomState)
    case answerResult(userId: String, isCorrect: Bool, lives: Int, scoreGained: Int, totalScore: Int)
    case playerOut(userId: String)
    case skipUsed(userId: String, skips: Int)
    case gameOver(winner: String?, participants: [WSParticipant])
    case turnChanged(activeUserId: String, turnIndex: Int)
    case yourTurn
    case playerDisconnected(userId: String)
    case roundSummary(roundIndex: Int, participants: [WSParticipant])
    case turnTimeFactor(userId: String, timeFactor: Double, totalScore: Int)
    case playerRemoved(userId: String)
    case youWereRemoved
    case roomCancelled
    case error(message: String)

    private enum TopKeys: String, CodingKey {
        case type, state, userId, participants, isCorrect, lives, skips, scoreGained, totalScore
        case winner, activeUserId, turnIndex, roundIndex, timeFactor, message, position
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TopKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "room_state":
            self = .roomState(try c.decode(WSRoomState.self, forKey: .state))
        case "player_joined":
            self = .playerJoined(
                userId: try c.decode(String.self, forKey: .userId),
                participants: try c.decode([WSParticipant].self, forKey: .participants)
            )
        case "game_started":
            self = .gameStarted(try c.decode(WSRoomState.self, forKey: .state))
        case "answer_result":
            self = .answerResult(
                userId: try c.decode(String.self, forKey: .userId),
                isCorrect: try c.decode(Bool.self, forKey: .isCorrect),
                lives: try c.decode(Int.self, forKey: .lives),
                scoreGained: (try? c.decode(Int.self, forKey: .scoreGained)) ?? 0,
                totalScore: (try? c.decode(Int.self, forKey: .totalScore)) ?? 0
            )
        case "player_out":
            self = .playerOut(userId: try c.decode(String.self, forKey: .userId))
        case "skip_used":
            self = .skipUsed(
                userId: try c.decode(String.self, forKey: .userId),
                skips: try c.decode(Int.self, forKey: .skips)
            )
        case "game_over":
            self = .gameOver(
                winner: try? c.decode(String.self, forKey: .winner),
                participants: try c.decode([WSParticipant].self, forKey: .participants)
            )
        case "turn_changed":
            self = .turnChanged(
                activeUserId: try c.decode(String.self, forKey: .activeUserId),
                turnIndex: try c.decode(Int.self, forKey: .turnIndex)
            )
        case "your_turn":
            self = .yourTurn
        case "player_disconnected":
            self = .playerDisconnected(userId: try c.decode(String.self, forKey: .userId))
        case "round_summary":
            self = .roundSummary(
                roundIndex: try c.decode(Int.self, forKey: .roundIndex),
                participants: try c.decode([WSParticipant].self, forKey: .participants)
            )
        case "turn_time_factor":
            self = .turnTimeFactor(
                userId: try c.decode(String.self, forKey: .userId),
                timeFactor: try c.decode(Double.self, forKey: .timeFactor),
                totalScore: (try? c.decode(Int.self, forKey: .totalScore)) ?? 0
            )
        case "player_removed":
            self = .playerRemoved(userId: try c.decode(String.self, forKey: .userId))
        case "you_were_removed":
            self = .youWereRemoved
        case "room_cancelled":
            self = .roomCancelled
        case "error":
            self = .error(message: (try? c.decode(String.self, forKey: .message)) ?? "Unknown error")
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown WS message type: \(type)")
        }
    }
}

// MARK: – Client → Server message types

enum WSClientMessage: Encodable {
    case startGame(name: String, questionsPerRound: Int, mode: String)
    case submitAnswer(questionRef: String, userAnswer: String, answerTimeMs: Int, clientReportsCorrect: Bool)
    case useSkip

    private enum CodingKeys: String, CodingKey {
        case type, name, questionsPerRound, mode, questionRef, userAnswer, answerTimeMs, clientReportsCorrect
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .startGame(let name, let qpr, let mode):
            try c.encode("start_game", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(qpr, forKey: .questionsPerRound)
            try c.encode(mode, forKey: .mode)
        case .submitAnswer(let ref, let ans, let timeMs, let correct):
            try c.encode("submit_answer", forKey: .type)
            try c.encode(ref, forKey: .questionRef)
            try c.encode(ans, forKey: .userAnswer)
            try c.encode(timeMs, forKey: .answerTimeMs)
            try c.encode(correct, forKey: .clientReportsCorrect)
        case .useSkip:
            try c.encode("use_skip", forKey: .type)
        }
    }
}

struct WSPlayer: Decodable {
    let userId: String
    let username: String
    let avatarEmoji: String?
    let avatarUrl: String?
}

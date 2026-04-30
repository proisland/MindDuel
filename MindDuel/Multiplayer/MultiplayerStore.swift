import SwiftUI

@MainActor final class MultiplayerStore: ObservableObject {
    static let shared = MultiplayerStore()

    @Published var currentRoom: MultiplayerRoom?
    @Published var pendingInviteCount: Int = 1   // mock – one pending invite on first launch

    private var botTask: Task<Void, Never>?

    private init() {}

    // MARK: – Lobby

    func createRoom(mode: GameMode, ownUsername: String) {
        let code = String(UUID().uuidString.prefix(4).uppercased())
        let host = MultiplayerPlayer(id: "me",  username: ownUsername, isHost: true,  isReady: true,  isYou: true)
        let bot1 = MultiplayerPlayer(id: "u1",  username: "magnus",    isHost: false, isReady: false)
        let bot2 = MultiplayerPlayer(id: "u2",  username: "sara",      isHost: false, isReady: false)
        currentRoom = MultiplayerRoom(id: code, mode: mode, startLevel: 1,
                                      players: [host, bot1, bot2], status: .lobby)
        seedBotReadyStates()
    }

    func joinMockRoom(ownUsername: String) {
        let host = MultiplayerPlayer(id: "u1",  username: "magnus",    isHost: true,  isReady: true)
        let you  = MultiplayerPlayer(id: "me",  username: ownUsername, isHost: false, isReady: false, isYou: true)
        let bot2 = MultiplayerPlayer(id: "u2",  username: "alex",      isHost: false, isReady: false)
        currentRoom = MultiplayerRoom(id: "A3BF", mode: .math, startLevel: 1,
                                      players: [host, you, bot2], status: .lobby)
        seedBotReadyStates()
    }

    func toggleReady() {
        guard let idx = currentRoom?.players.firstIndex(where: { $0.isYou }) else { return }
        currentRoom?.players[idx].isReady.toggle()
    }

    var allReady: Bool { currentRoom?.players.allSatisfy(\.isReady) ?? false }

    func startGame() {
        currentRoom?.status = .playing
        currentRoom?.currentTurnIndex = 0
        scheduleBotTurn()
    }

    // MARK: – Gameplay

    func submitAnswer(correct: Bool, answerTime: Double) {
        guard var room = currentRoom, room.isMyTurn else { return }
        applyResult(to: &room, playerID: "me", correct: correct, answerTime: answerTime)
        advanceTurn(&room)
        currentRoom = room
        scheduleBotTurn()
    }

    func useSkip() {
        guard var room = currentRoom, room.isMyTurn else { return }
        guard let idx = room.players.firstIndex(where: { $0.isYou }) else { return }
        room.players[idx].skips = max(0, room.players[idx].skips - 1)
        if room.players[idx].skips == 0 { room.players[idx].isEliminated = true }
        advanceTurn(&room)
        currentRoom = room
        scheduleBotTurn()
    }

    func leaveRoom() {
        botTask?.cancel()
        botTask = nil
        currentRoom = nil
    }

    // MARK: – Private

    private func seedBotReadyStates() {
        botTask?.cancel()
        botTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == "u1" }) {
                currentRoom?.players[idx].isReady = true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == "u2" }) {
                currentRoom?.players[idx].isReady = true
            }
        }
    }

    private func scheduleBotTurn() {
        botTask?.cancel()
        guard let room = currentRoom,
              !room.isMyTurn,
              room.status == .playing,
              room.winner == nil else { return }

        let delay = UInt64(Double.random(in: 1_500_000_000...3_500_000_000))
        botTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            executeBotTurn()
        }
    }

    private func executeBotTurn() {
        guard var room = currentRoom,
              !room.isMyTurn,
              room.status == .playing,
              let bot = room.currentPlayer,
              let idx = room.players.firstIndex(where: { $0.id == bot.id }) else { return }

        let correct = Double.random(in: 0...1) > 0.28
        let answerTime = Double.random(in: 0.8...3.5)
        applyResult(to: &room, playerIdx: idx, correct: correct, answerTime: answerTime)
        advanceTurn(&room)
        currentRoom = room
        scheduleBotTurn()
    }

    private func applyResult(to room: inout MultiplayerRoom, playerID: String, correct: Bool, answerTime: Double) {
        guard let idx = room.players.firstIndex(where: { $0.id == playerID }) else { return }
        applyResult(to: &room, playerIdx: idx, correct: correct, answerTime: answerTime)
    }

    private func applyResult(to room: inout MultiplayerRoom, playerIdx: Int, correct: Bool, answerTime: Double) {
        if correct {
            let pts = Int(100.0 / max(0.5, answerTime))
            room.players[playerIdx].score += pts
        } else {
            room.players[playerIdx].lives = max(0, room.players[playerIdx].lives - 1)
            if room.players[playerIdx].lives == 0 {
                room.players[playerIdx].isEliminated = true
            }
        }
    }

    private func advanceTurn(_ room: inout MultiplayerRoom) {
        let active = room.activePlayers
        if active.count <= 1 || room.winner != nil {
            room.status = .finished
            return
        }
        room.currentTurnIndex = (room.currentTurnIndex + 1) % active.count
    }
}

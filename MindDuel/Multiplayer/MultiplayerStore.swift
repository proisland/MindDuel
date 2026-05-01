import SwiftUI
import UserNotifications

@MainActor final class MultiplayerStore: ObservableObject {
    static let shared = MultiplayerStore()

    @Published var currentRoom: MultiplayerRoom?
    @Published var backgroundRooms: [MultiplayerRoom] = []
    @Published var pendingInviteCount: Int = 1
    @Published var recentActivity: [MultiplayerActivityItem] = []
    @Published var lastGameEvent: GameEvent?

    private var botTask: Task<Void, Never>?

    private init() {}

    // MARK: – Computed

    var playingRooms: [MultiplayerRoom] {
        var result = backgroundRooms.filter { $0.status == .playing }
        if let room = currentRoom, room.status == .playing { result.append(room) }
        return result
    }

    // MARK: – Lobby

    func createRoom(mode: GameMode, ownUsername: String, invitedUsername: String? = nil) {
        let code = String(UUID().uuidString.prefix(4).uppercased())
        let host = MultiplayerPlayer(id: "me", username: ownUsername, isHost: true, isReady: true, isYou: true)
        currentRoom = MultiplayerRoom(id: code, mode: mode, startLevel: 1, players: [host], status: .lobby)
        if let invited = invitedUsername {
            inviteFriend(username: invited, playerID: "u_\(invited)")
        }
    }

    func joinMockRoom(ownUsername: String) {
        let host = MultiplayerPlayer(id: "u1", username: "magnus", isHost: true,  isReady: true)
        let you  = MultiplayerPlayer(id: "me", username: ownUsername, isHost: false, isReady: false, isYou: true)
        let bot2 = MultiplayerPlayer(id: "u2", username: "alex",    isHost: false, isReady: false)
        currentRoom = MultiplayerRoom(id: "A3BF", mode: .math, startLevel: 1,
                                      players: [host, you, bot2], status: .lobby)
        seedBotReadyStates()
    }

    func inviteFriend(username: String, playerID: String) {
        guard currentRoom != nil else { return }
        guard !(currentRoom?.players.contains(where: { $0.username == username }) ?? false) else { return }
        let player = MultiplayerPlayer(id: playerID, username: username, isHost: false, isReady: false)
        currentRoom?.players.append(player)
        simulatePlayerReady(playerID: playerID)
    }

    private func simulatePlayerReady(playerID: String) {
        botTask?.cancel()
        botTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == playerID }) {
                currentRoom?.players[idx].isReady = true
            }
        }
    }

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
            // If user already pressed Ready before bots, auto-start now
            let youReady = currentRoom?.players.first(where: { $0.isYou })?.isReady == true
            let isHost   = currentRoom?.players.first(where: { $0.isYou })?.isHost == true
            if allReady && youReady && !isHost {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                startGame()
            }
        }
    }

    func toggleReady() {
        guard let idx = currentRoom?.players.firstIndex(where: { $0.isYou }) else { return }
        currentRoom?.players[idx].isReady.toggle()
        let nowReady = currentRoom?.players[idx].isReady == true
        if nowReady && allReady {
            let isHost = currentRoom?.players[idx].isHost == true
            if !isHost {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    startGame()
                }
            }
        }
    }

    var allReady: Bool { currentRoom?.players.allSatisfy(\.isReady) ?? false }

    func startGame() {
        currentRoom?.status = .playing
        currentRoom?.currentTurnIndex = 0
        scheduleBotTurn()
    }

    // MARK: – Room lifecycle

    func dismissGame() {
        guard let room = currentRoom else { return }
        botTask?.cancel()
        botTask = nil
        if room.status == .playing {
            if !backgroundRooms.contains(where: { $0.id == room.id }) {
                backgroundRooms.append(room)
            }
            scheduleGameReminderNotification()
        }
        currentRoom = nil
    }

    func rejoin(roomID: String) {
        if let idx = backgroundRooms.firstIndex(where: { $0.id == roomID }) {
            currentRoom = backgroundRooms.remove(at: idx)
            cancelGameReminderNotification()
            scheduleBotTurn()
        }
    }

    func leaveRoom() {
        botTask?.cancel()
        botTask = nil
        if let id = currentRoom?.id {
            backgroundRooms.removeAll { $0.id == id }
        }
        currentRoom = nil
    }

    func leaveBackgroundRoom(id: String) {
        backgroundRooms.removeAll { $0.id == id }
    }

    // MARK: – Gameplay

    func submitAnswer(correct: Bool, answerTime: Double) {
        guard var room = currentRoom, room.isMyTurn else { return }
        applyResult(to: &room, playerID: "me", correct: correct, answerTime: answerTime)
        advanceTurn(&room)
        currentRoom = room
        if room.status == .finished { recordActivity(room) }
        else { scheduleBotTurn() }
    }

    func useSkip() {
        guard var room = currentRoom, room.isMyTurn else { return }
        guard let idx = room.players.firstIndex(where: { $0.isYou }) else { return }
        room.players[idx].skips = max(0, room.players[idx].skips - 1)
        if room.players[idx].skips == 0 { room.players[idx].isEliminated = true }
        advanceTurn(&room)
        currentRoom = room
        if room.status == .finished { recordActivity(room) }
        else { scheduleBotTurn() }
    }

    // MARK: – Notifications

    func scheduleGameReminderNotification() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification_your_turn_title")
            content.body = String(localized: "notification_game_waiting_body")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15, repeats: false)
            let request = UNNotificationRequest(identifier: "game-reminder", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelGameReminderNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["game-reminder"])
    }

    // MARK: – Private helpers

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
        let prevLives = room.players[idx].lives
        applyResult(to: &room, playerIdx: idx, correct: correct, answerTime: answerTime)

        if !correct && room.players[idx].lives < prevLives {
            lastGameEvent = GameEvent(
                message: String(format: String(localized: "game_event_lost_life_format"), bot.username),
                isPositive: true
            )
        }

        advanceTurn(&room)
        currentRoom = room

        if room.status == .finished {
            recordActivity(room)
        } else {
            if room.isMyTurn { sendTurnNotification() }
            scheduleBotTurn()
        }
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

    private func recordActivity(_ room: MultiplayerRoom) {
        guard let me = room.players.first(where: { $0.isYou }) else { return }
        let opponent = room.players.first(where: { !$0.isYou })
        let item = MultiplayerActivityItem(
            opponentUsername: opponent?.username ?? "bot",
            mode: room.mode,
            didWin: room.winner?.isYou == true,
            score: me.score,
            timestamp: Date()
        )
        recentActivity.insert(item, at: 0)
        if recentActivity.count > 10 { recentActivity = Array(recentActivity.prefix(10)) }
        ProgressionStore.shared.recordMultiplayerScore(mode: room.mode, score: me.score)
    }

    private func sendTurnNotification() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification_your_turn_title")
            content.body = String(localized: "notification_your_turn_body")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}

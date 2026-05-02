import SwiftUI
import UserNotifications

@MainActor final class MultiplayerStore: ObservableObject {
    static let shared = MultiplayerStore()

    @Published var currentRoom: MultiplayerRoom?
    @Published var backgroundRooms: [MultiplayerRoom] = [] { didSet { persistBackgroundRooms() } }
    @Published var pendingInviteCount: Int = 0
    @Published var recentActivity: [MultiplayerActivityItem] = [] { didSet { persistRecentActivity() } }
    @Published var lastGameEvent: GameEvent?

    private var botTask: Task<Void, Never>?
    private var backgroundSimTask: Task<Void, Never>?

    private static let backgroundRoomsKey = "multiplayer.backgroundRooms"
    private static let recentActivityKey  = "multiplayer.recentActivity"

    private init() {
        loadPersistedState()
    }

    // MARK: – Persistence

    private func persistBackgroundRooms() {
        guard let data = try? JSONEncoder().encode(backgroundRooms) else { return }
        UserDefaults.standard.set(data, forKey: Self.backgroundRoomsKey)
    }

    private func persistRecentActivity() {
        guard let data = try? JSONEncoder().encode(recentActivity) else { return }
        UserDefaults.standard.set(data, forKey: Self.recentActivityKey)
    }

    private func loadPersistedState() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.backgroundRoomsKey),
           let decoded = try? JSONDecoder().decode([MultiplayerRoom].self, from: data) {
            backgroundRooms = decoded
        }
        if let data = d.data(forKey: Self.recentActivityKey),
           let decoded = try? JSONDecoder().decode([MultiplayerActivityItem].self, from: data) {
            recentActivity = decoded
        }
    }

    // MARK: – Computed

    var playingRooms: [MultiplayerRoom] {
        var result = backgroundRooms.filter { $0.status == .playing }
        if let room = currentRoom, room.status == .playing { result.append(room) }
        return result
    }

    var hasMyTurnInBackground: Bool {
        backgroundRooms.contains { $0.status == .playing && $0.isMyTurn }
    }

    // MARK: – Lobby

    func createRoom(mode: GameMode, ownUsername: String, invitedUsername: String? = nil) {
        let code = String(UUID().uuidString.prefix(4).uppercased())
        var host = MultiplayerPlayer(id: "me", username: ownUsername, isHost: true, isReady: true, isYou: true)
        applyOwnStats(to: &host)
        currentRoom = MultiplayerRoom(id: code, mode: mode, startLevel: 1, players: [host], status: .lobby)
        if let invited = invitedUsername {
            inviteFriend(username: invited, playerID: "u_\(invited)")
        }
    }

    func joinMockRoom(ownUsername: String, mode: GameMode = .pi) {
        var host = MultiplayerPlayer(id: "u1", username: "magnus", isHost: true,  isReady: true)
        host.piLevel = 7;  host.mathLevel = 5;  host.piBestScore = 1240; host.mathBestScore = 980
        var you  = MultiplayerPlayer(id: "me", username: ownUsername, isHost: false, isReady: false, isYou: true)
        applyOwnStats(to: &you)
        var bot2 = MultiplayerPlayer(id: "u2", username: "alex",    isHost: false, isReady: false)
        bot2.piLevel = 4;  bot2.mathLevel = 8;  bot2.piBestScore = 620;  bot2.mathBestScore = 1510
        currentRoom = MultiplayerRoom(id: "A3BF", mode: mode, startLevel: 1,
                                      players: [host, you, bot2], status: .lobby)
        seedBotReadyStates()
    }

    func inviteFriend(username: String, playerID: String) {
        guard currentRoom != nil else { return }
        guard !(currentRoom?.players.contains(where: { $0.username == username }) ?? false) else { return }
        var player = MultiplayerPlayer(id: playerID, username: username, isHost: false, isReady: false)
        // Mock invitee stats — deterministic from username so the lobby line
        // doesn't jitter between renders. Replace with server data in M5+.
        let seed = abs(username.hashValue)
        player.piLevel      = 1 + seed % 12
        player.mathLevel    = 1 + (seed / 13) % 12
        player.piBestScore  = (seed % 1500)
        player.mathBestScore = ((seed / 17) % 1500)
        currentRoom?.players.append(player)
        simulatePlayerReady(playerID: playerID)
    }

    /// Snapshot the local user's progression stats onto the player record
    /// so the lobby (#21) and any peers see consistent numbers for the round.
    private func applyOwnStats(to player: inout MultiplayerPlayer) {
        let p = ProgressionStore.shared
        player.piLevel       = p.piLevel
        player.mathLevel     = p.mathLevel
        player.chemLevel     = p.chemLevel
        player.piBestScore   = p.piBestScore
        player.mathBestScore = p.mathBestScore
        player.chemBestScore = p.chemBestScore
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
            // Register at OS level immediately — survives app kill.
            // Delay 1s if already user's turn, else 30s for bots to finish.
            scheduleGameReminderNotification(delay: room.isMyTurn ? 1 : 30)
            startBackgroundSimulation(roomID: room.id)
        }
        currentRoom = nil
    }

    func rejoin(roomID: String) {
        backgroundSimTask?.cancel()
        backgroundSimTask = nil
        cancelGameReminderNotification()
        if let idx = backgroundRooms.firstIndex(where: { $0.id == roomID }) {
            currentRoom = backgroundRooms.remove(at: idx)
            scheduleBotTurn()
        }
    }

    func leaveRoom() {
        botTask?.cancel()
        botTask = nil
        backgroundSimTask?.cancel()
        backgroundSimTask = nil
        cancelGameReminderNotification()
        if let id = currentRoom?.id {
            backgroundRooms.removeAll { $0.id == id }
        }
        currentRoom = nil
    }

    func leaveBackgroundRoom(id: String) {
        backgroundRooms.removeAll { $0.id == id }
    }

    // MARK: – Standalone solo (Pi/Math) sessions

    /// Save a standalone solo Pi session to backgroundRooms. Returns the new room id.
    func saveStandaloneSoloPi(ownUsername: String,
                              lives: Int, skips: Int,
                              score: Int, correctCount: Int,
                              currentDigit: Int) -> String {
        let id = "SOLO-" + String(UUID().uuidString.prefix(4).uppercased())
        var player = MultiplayerPlayer(id: "me", username: ownUsername,
                                       isHost: true, isReady: true, isYou: true)
        player.lives = lives
        player.skips = skips
        player.score = score
        player.correctCount = correctCount
        var room = MultiplayerRoom(id: id, mode: .pi, startLevel: 1,
                                   players: [player], status: .playing)
        room.myPiDigitIndex = currentDigit
        room.isStandaloneSolo = true
        backgroundRooms.append(room)
        return id
    }

    /// Save a standalone solo Chemistry session to backgroundRooms.
    func saveStandaloneSoloChem(ownUsername: String,
                                lives: Int, skips: Int,
                                score: Int, correctCount: Int,
                                startLevel: Int) -> String {
        let id = "SOLO-" + String(UUID().uuidString.prefix(4).uppercased())
        var player = MultiplayerPlayer(id: "me", username: ownUsername,
                                       isHost: true, isReady: true, isYou: true)
        player.lives = lives
        player.skips = skips
        player.score = score
        player.correctCount = correctCount
        var room = MultiplayerRoom(id: id, mode: .chemistry, startLevel: startLevel,
                                   players: [player], status: .playing)
        room.isStandaloneSolo = true
        backgroundRooms.append(room)
        return id
    }

    /// Save a standalone solo Math session to backgroundRooms. Returns the new room id.
    func saveStandaloneSoloMath(ownUsername: String,
                                lives: Int, skips: Int,
                                score: Int, correctCount: Int,
                                startLevel: Int) -> String {
        let id = "SOLO-" + String(UUID().uuidString.prefix(4).uppercased())
        var player = MultiplayerPlayer(id: "me", username: ownUsername,
                                       isHost: true, isReady: true, isYou: true)
        player.lives = lives
        player.skips = skips
        player.score = score
        player.correctCount = correctCount
        var room = MultiplayerRoom(id: id, mode: .math, startLevel: startLevel,
                                   players: [player], status: .playing)
        room.isStandaloneSolo = true
        backgroundRooms.append(room)
        return id
    }

    /// Remove and return a standalone solo room (used when resuming).
    func popStandaloneSolo(roomID: String) -> MultiplayerRoom? {
        guard let idx = backgroundRooms.firstIndex(where: { $0.id == roomID && $0.isStandaloneSolo })
        else { return nil }
        return backgroundRooms.remove(at: idx)
    }

    // MARK: – Gameplay

    func submitAnswer(correct: Bool, answerTime: Double) {
        guard var room = currentRoom, room.isMyTurn else { return }
        ProgressionStore.shared.consumeQuestion()
        applyResult(to: &room, playerID: "me", correct: correct, answerTime: answerTime)
        advanceTurn(&room)
        currentRoom = room
        if room.status == .finished { recordActivity(room) }
        else { scheduleBotTurn() }
    }

    func useSkip() {
        guard var room = currentRoom, room.isMyTurn else { return }
        ProgressionStore.shared.consumeQuestion()
        guard let idx = room.players.firstIndex(where: { $0.isYou }) else { return }
        room.players[idx].skips = max(0, room.players[idx].skips - 1)
        if room.players[idx].skips == 0 { room.players[idx].isEliminated = true }
        advanceTurn(&room)
        currentRoom = room
        if room.status == .finished { recordActivity(room) }
        else { scheduleBotTurn() }
    }

    // MARK: – Notifications

    func scheduleGameReminderNotification(delay: Double = 30) {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification_your_turn_title")
            content.body = String(localized: "notification_your_turn_body")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
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
            room.players[playerIdx].correctCount += 1
        } else {
            room.players[playerIdx].lives = max(0, room.players[playerIdx].lives - 1)
            if room.players[playerIdx].lives == 0 {
                room.players[playerIdx].isEliminated = true
            }
        }
    }

    private func advanceTurn(_ room: inout MultiplayerRoom) {
        let active = room.activePlayers
        let isMultiplayer = room.players.count > 1
        // Solo game: only finish when the player is eliminated (active is empty)
        // Multiplayer: finish when one player remains (they're the winner)
        if active.isEmpty || (isMultiplayer && active.count == 1) {
            room.status = .finished
            return
        }
        room.currentTurnIndex = (room.currentTurnIndex + 1) % max(1, active.count)
    }

    private func startBackgroundSimulation(roomID: String) {
        backgroundSimTask?.cancel()
        backgroundSimTask = Task {
            while true {
                guard !Task.isCancelled else { return }
                guard let idx = backgroundRooms.firstIndex(where: { $0.id == roomID }) else { return }
                let room = backgroundRooms[idx]
                guard room.status == .playing else { return }
                // Solo rooms (multiplayer or standalone): nothing to simulate; the "turn"
                // belongs to the human and we already scheduled the reminder notification.
                guard room.players.count > 1 else { return }
                if room.isMyTurn {
                    sendTurnNotification()
                    return
                }
                let delay = UInt64(Double.random(in: 1_200_000_000...2_500_000_000))
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                guard let roomIdx = backgroundRooms.firstIndex(where: { $0.id == roomID }) else { return }
                var updatedRoom = backgroundRooms[roomIdx]
                guard updatedRoom.status == .playing,
                      let bot = updatedRoom.currentPlayer,
                      !bot.isYou,
                      let botIdx = updatedRoom.players.firstIndex(where: { $0.id == bot.id }) else {
                    if backgroundRooms[roomIdx].isMyTurn { sendTurnNotification() }
                    return
                }
                let correct = Double.random(in: 0...1) > 0.28
                let answerTime = Double.random(in: 0.8...3.5)
                applyResult(to: &updatedRoom, playerIdx: botIdx, correct: correct, answerTime: answerTime)
                advanceTurn(&updatedRoom)
                backgroundRooms[roomIdx] = updatedRoom
                if updatedRoom.status == .finished {
                    backgroundRooms.remove(at: roomIdx)
                    recordActivity(updatedRoom)
                    return
                }
            }
        }
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
        ProgressionStore.shared.recordMultiplayerScore(mode: room.mode, score: me.score, correctCount: me.correctCount)
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

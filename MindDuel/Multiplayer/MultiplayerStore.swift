import SwiftUI
import UserNotifications

@MainActor final class MultiplayerStore: ObservableObject {
    static let shared = MultiplayerStore()

    @Published var currentRoom: MultiplayerRoom?
    @Published var backgroundRooms: [MultiplayerRoom] = [] { didSet { persistBackgroundRooms() } }
    /// Pending multiplayer invites (#56). The home-screen badge counts these
    /// and the "Bli med" entry surfaces them as a list. Seeded with mock
    /// data on first launch so the feature is testable.
    @Published var pendingInvites: [MultiplayerInvite] = MultiplayerStore.mockInvites()
    var pendingInviteCount: Int { pendingInvites.count }

    private static func mockInvites() -> [MultiplayerInvite] {
        [
            MultiplayerInvite(roomCode: "9F2A", mode: .math,
                              hostUsername: "magnus",
                              invitedAt: Date().addingTimeInterval(-180)),
            MultiplayerInvite(roomCode: "B3C1", mode: .pi,
                              hostUsername: "sara",
                              invitedAt: Date().addingTimeInterval(-1200)),
            MultiplayerInvite(roomCode: "K7D9", mode: .chemistry,
                              hostUsername: "alex",
                              invitedAt: Date().addingTimeInterval(-3600))
        ]
    }

    /// Accept a pending invite and drop the user into the corresponding lobby.
    /// Mock implementation just calls joinMockRoom with the invite's mode.
    func acceptInvite(_ invite: MultiplayerInvite, ownUsername: String) {
        pendingInvites.removeAll { $0.id == invite.id }
        joinMockRoom(ownUsername: ownUsername, mode: invite.mode)
    }

    func declineInvite(_ invite: MultiplayerInvite) {
        pendingInvites.removeAll { $0.id == invite.id }
    }
    @Published var recentActivity: [MultiplayerActivityItem] = [] { didSet { persistRecentActivity() } }
    @Published var lastGameEvent: GameEvent?
    /// #96: when a full round (every active player has completed their turn)
    /// finishes, this is set to the round's answer log so the GameView can
    /// surface a summary modal. Cleared by `dismissRoundSummary()`.
    @Published var lastRoundSummary: RoundSummary? = nil

    struct RoundSummary {
        let roundIndex: Int
        let problems: [SharedProblem]
        let answers: [RoundAnswer]
        let players: [MultiplayerPlayer]
    }

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
        if !(currentRoom?.invitedUsernames.contains(username) ?? false) {
            currentRoom?.invitedUsernames.append(username)
        }
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
        player.geoLevel      = p.geoLevel
        player.brainLevel    = p.brainLevel
        player.piBestScore   = p.piBestScore
        player.mathBestScore = p.mathBestScore
        player.chemBestScore = p.chemBestScore
        player.geoBestScore  = p.geoBestScore
        player.brainBestScore = p.brainBestScore
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
        // #81: drop invitees who never accepted so the turn loop isn't blocked.
        // Their usernames are preserved on the room (`invitedUsernames`) so the
        // Active Games row can still show participants for host-created rooms
        // that were started before everyone responded (#109).
        if var room = currentRoom {
            let dropped = room.players.filter { !$0.isHost && !$0.isReady }.map(\.username)
            room.invitedUsernames = Array(Set(room.invitedUsernames + dropped))
            room.players.removeAll { !$0.isHost && !$0.isReady }
            currentRoom = room
        }
        currentRoom?.status = .playing
        currentRoom?.currentTurnIndex = 0
        currentRoom?.currentTurnQuestionsAnswered = 0
        currentRoom?.currentQuestionIndex = 0
        currentRoom?.currentRoundIndex = 1
        currentRoom?.roundAnswers = []
        seedRoundProblems()
        scheduleBotTurn()
    }

    func dismissRoundSummary() {
        lastRoundSummary = nil
    }

    /// #93: generate the round's shared problems on the host. Every player
    /// (incl. mock bots) reads from the same list so questions are
    /// identical across the room.
    private func seedRoundProblems() {
        guard var room = currentRoom else { return }
        let count = max(1, room.questionsPerTurn)
        let piStart: Int
        if room.mode == .pi {
            piStart = room.myPiDigitIndex > 0
                ? room.myPiDigitIndex
                : max(0, (ProgressionStore.shared.piLevel - 1) * 50)
        } else {
            piStart = 0
        }
        room.roundProblems = SharedProblemFactory.makeRound(
            mode: room.mode,
            level: room.startLevel,
            count: count,
            piStartIndex: piStart
        )
        currentRoom = room
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
        room.lastActivityAt = Date()
        backgroundRooms.append(room)
        return id
    }

    /// Save a standalone solo Geography session to backgroundRooms.
    func saveStandaloneSoloGeo(ownUsername: String,
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
        var room = MultiplayerRoom(id: id, mode: .geography, startLevel: startLevel,
                                   players: [player], status: .playing)
        room.isStandaloneSolo = true
        room.lastActivityAt = Date()
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
        room.lastActivityAt = Date()
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
        room.lastActivityAt = Date()
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
        recordRoundAnswer(to: &room, playerIdx: room.players.firstIndex(where: { $0.isYou }) ?? 0,
                          correct: correct, skipped: false)
        applyResult(to: &room, playerID: "me", correct: correct, answerTime: answerTime)
        advanceQuestionOrTurn(&room)
        currentRoom = room
        if room.status == .finished { recordActivity(room) }
        else { scheduleBotTurn() }
    }

    func useSkip() {
        guard var room = currentRoom, room.isMyTurn else { return }
        ProgressionStore.shared.consumeQuestion()
        guard let idx = room.players.firstIndex(where: { $0.isYou }) else { return }
        recordRoundAnswer(to: &room, playerIdx: idx, correct: false, skipped: true)
        room.players[idx].skips = max(0, room.players[idx].skips - 1)
        if room.players[idx].skips == 0 { room.players[idx].isEliminated = true }
        advanceQuestionOrTurn(&room)
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
        recordRoundAnswer(to: &room, playerIdx: idx, correct: correct, skipped: false)
        applyResult(to: &room, playerIdx: idx, correct: correct, answerTime: answerTime)

        if !correct && room.players[idx].lives < prevLives {
            lastGameEvent = GameEvent(
                message: String(format: String(localized: "game_event_lost_life_format"), bot.username),
                isPositive: true
            )
        }

        advanceQuestionOrTurn(&room)
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
            let pts = Int(50.0 / max(0.5, answerTime))
            room.players[playerIdx].score += pts
            room.players[playerIdx].correctCount += 1
        } else {
            room.players[playerIdx].lives = max(0, room.players[playerIdx].lives - 1)
            if room.players[playerIdx].lives == 0 {
                room.players[playerIdx].isEliminated = true
            }
        }
        room.lastActivityAt = Date()
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

    /// #95: handle the "answer N questions before passing" flow. Advances
    /// the question pointer and only hands off control to the next player
    /// once the current player has answered `questionsPerTurn` questions.
    /// When a full round (every active player has finished their turn)
    /// completes, snapshots the round answers for the summary view (#96)
    /// and seeds the next round's shared problems (#93).
    private func advanceQuestionOrTurn(_ room: inout MultiplayerRoom) {
        room.currentTurnQuestionsAnswered += 1
        let perTurn = max(1, room.questionsPerTurn)
        if room.currentTurnQuestionsAnswered < perTurn && !(room.currentPlayer?.isEliminated ?? false) {
            // Same player still has questions left this turn.
            room.currentQuestionIndex = room.currentTurnQuestionsAnswered
            return
        }
        // Player has finished their turn.
        let prevTurnIndex = room.currentTurnIndex
        advanceTurn(&room)
        room.currentTurnQuestionsAnswered = 0
        room.currentQuestionIndex = 0

        guard room.status == .playing else { return }

        // Detect end-of-round: the new turn index wrapped back to (or before)
        // the previous, meaning every active player has now had a turn this
        // round. We snapshot the round before clearing it.
        let active = room.activePlayers
        let wrapped = active.isEmpty || (room.currentTurnIndex <= prevTurnIndex)
        if wrapped {
            lastRoundSummary = RoundSummary(
                roundIndex: room.currentRoundIndex,
                problems: room.roundProblems,
                answers: room.roundAnswers,
                players: room.players
            )
            room.currentRoundIndex += 1
            room.roundAnswers = []
            currentRoom = room
            seedRoundProblems()
            // seedRoundProblems mutates currentRoom, copy back so caller's
            // `currentRoom = room` doesn't overwrite it.
            if let updated = currentRoom { room = updated }
        }
    }

    private func recordRoundAnswer(to room: inout MultiplayerRoom, playerIdx: Int, correct: Bool, skipped: Bool) {
        guard playerIdx >= 0, playerIdx < room.players.count else { return }
        let player = room.players[playerIdx]
        let qIndex = min(room.currentTurnQuestionsAnswered, max(0, room.questionsPerTurn - 1))
        let prompt: String
        if qIndex < room.roundProblems.count {
            prompt = room.roundProblems[qIndex].prompt
        } else {
            prompt = ""
        }
        room.roundAnswers.append(RoundAnswer(
            playerID: player.id,
            username: player.username,
            questionInRound: qIndex,
            correct: correct,
            skipped: skipped,
            problemPrompt: prompt
        ))
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
                recordRoundAnswer(to: &updatedRoom, playerIdx: botIdx, correct: correct, skipped: false)
                applyResult(to: &updatedRoom, playerIdx: botIdx, correct: correct, answerTime: answerTime)
                // Background simulation has no foreground room to mirror,
                // so the simpler advanceTurn is fine here — round summary
                // will surface the next time the user rejoins.
                updatedRoom.currentTurnQuestionsAnswered += 1
                if updatedRoom.currentTurnQuestionsAnswered >= max(1, updatedRoom.questionsPerTurn) {
                    advanceTurn(&updatedRoom)
                    updatedRoom.currentTurnQuestionsAnswered = 0
                    updatedRoom.currentQuestionIndex = 0
                } else {
                    updatedRoom.currentQuestionIndex = updatedRoom.currentTurnQuestionsAnswered
                }
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

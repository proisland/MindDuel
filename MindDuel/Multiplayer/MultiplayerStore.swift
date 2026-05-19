import Combine
import SwiftUI
import UserNotifications

@MainActor final class MultiplayerStore: ObservableObject {
    static let shared = MultiplayerStore()

    @Published var currentRoom: MultiplayerRoom?
    @Published var backgroundRooms: [MultiplayerRoom] = [] { didSet { persistBackgroundRooms() } }
    @Published var pendingInvites: [MultiplayerInvite] = []

    /// Live WebSocket connection for the current room.
    let wsClient = WebSocketClient()
    /// Backend UUID for the current room (separate from the display code).
    private(set) var backendRoomId: String?

    // MARK: – API room creation / join

    /// Creates a real room via the backend and connects WS.
    func createRealRoom(mode: GameMode, serverSlug: String? = nil, ownUsername: String,
                        name: String = "", questionsPerRound: Int = 3,
                        invitedUsername: String? = nil) async throws {
        let modeSlug = serverSlug ?? mode.slug
        struct Body: Encodable { let mode: String; let startLevel: Int; let name: String; let questionsPerRound: Int }
        let room: RoomResponse = try await APIClient.shared.post(
            "ws/rooms",
            body: Body(mode: modeSlug, startLevel: 1, name: name, questionsPerRound: questionsPerRound)
        )
        createLocalRoom(mode: mode, ownUsername: ownUsername, roomCode: room.code,
                        name: name, questionsPerRound: questionsPerRound,
                        invitedUsername: invitedUsername)
        backendRoomId = room.id
        wsClient.connect(roomId: room.id)
        observeWS()
    }

    /// Joins an existing room by code.
    func joinRealRoom(code: String, ownUsername: String) async throws {
        let info: RoomInfo = try await APIClient.shared.get("ws/rooms/\(code)")
        let mode = GameMode(slug: info.mode) ?? .pi

        var players: [MultiplayerPlayer] = (info.participants ?? []).map { p in
            MultiplayerPlayer(
                id: p.userId,
                username: p.username,
                avatarUrl: p.avatarUrl,
                isHost: p.userId == info.hostId,
                isReady: true,  // All backend participants have accepted and joined
                lives: p.lives,
                skips: p.skips,
                score: p.score
            )
        }

        if let idx = players.firstIndex(where: { $0.username.lowercased() == ownUsername.lowercased() }) {
            players[idx].isYou = true
            applyOwnStats(to: &players[idx])
        } else {
            var me = MultiplayerPlayer(id: "me", username: ownUsername, isHost: false, isReady: false, isYou: true)
            applyOwnStats(to: &me)
            players.append(me)
        }

        var room = MultiplayerRoom(id: info.code, mode: mode, startLevel: 1, players: players, status: .lobby)
        room.customName = info.name ?? ""
        room.questionsPerTurn = info.questionsPerRound ?? 3
        currentRoom = room
        backendRoomId = info.id
        wsClient.connect(roomId: info.id)
        observeWS()
    }

    private func observeWS() {
        wsObserveTask?.cancel()
        wsObserveTask = Task {
            for await msg in wsMessages() {
                handle(wsMessage: msg)
            }
        }
    }

    private func wsMessages() -> AsyncStream<WSMessage> {
        AsyncStream { continuation in
            let cancellable = wsClient.$lastMessage
                .compactMap { $0 }
                .sink { continuation.yield($0) }
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }

    private func handle(wsMessage msg: WSMessage) {
        switch msg {

        case .roomState(let state):
            applyRoomState(state)

        case .playerJoined(let userId, let participants):
            if !(currentRoom?.players.contains(where: { $0.id == userId }) ?? false) {
                if let joined = participants.first(where: { $0.userId == userId }) {
                    var player = MultiplayerPlayer(
                        id: joined.userId, username: joined.username,
                        avatarUrl: joined.avatarUrl, isHost: false, isReady: true,
                        lives: joined.lives, skips: joined.skips, score: joined.score
                    )
                    let ownUsername = currentRoom?.players.first(where: { $0.isYou })?.username ?? ""
                    if joined.username.lowercased() == ownUsername.lowercased() { player.isYou = true }
                    currentRoom?.players.append(player)
                }
            }
            syncParticipantStats(participants)

        case .gameStarted(let state):
            applyRoomState(state)
            currentRoom?.status = .playing
            seedRoundProblems()

        case .answerResult(let userId, let isCorrect, let lives, _, let totalScore):
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == userId }) {
                currentRoom?.players[idx].lives = lives
                if totalScore > 0 { currentRoom?.players[idx].score = totalScore }
                if !isCorrect && lives == 0 {
                    currentRoom?.players[idx].isEliminated = true
                }
            }

        case .playerOut(let userId):
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == userId }) {
                currentRoom?.players[idx].isEliminated = true
                currentRoom?.players[idx].lives = 0
            }

        case .skipUsed(let userId, let skips):
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == userId }) {
                currentRoom?.players[idx].skips = skips
                if skips == 0 {
                    currentRoom?.players[idx].isEliminated = true
                }
            }

        case .gameOver(let winnerId, let participants):
            syncParticipantStats(participants)
            currentRoom?.status = .finished
            if let id = winnerId, let idx = currentRoom?.players.firstIndex(where: { $0.id == id }) {
                // winner is identified by id — UI uses activePlayers.count == 1 logic
                _ = idx
            }
            wsClient.disconnect()
            if let room = currentRoom { recordActivity(room) }

        case .turnChanged(let activeUserId, let turnIndex):
            // Map backend turnIndex (into participants array) to our activePlayers index.
            // We track whose turn it is by finding the active player matching activeUserId.
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == activeUserId }) {
                let activeCount = currentRoom?.activePlayers.count ?? 1
                if activeCount > 0 {
                    let activeIdx = currentRoom?.activePlayers.firstIndex(where: { $0.id == activeUserId }) ?? 0
                    currentRoom?.currentTurnIndex = activeIdx
                }
                _ = idx; _ = turnIndex
            }
            // Advance question state for new turn
            currentRoom?.currentTurnQuestionsAnswered = 0
            currentRoom?.currentQuestionIndex = 0

        case .yourTurn:
            cancelGameReminderNotification()
            seedRoundProblems()

        case .playerDisconnected(let userId):
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == userId }) {
                currentRoom?.players[idx].isEliminated = true
            }

        case .roundSummary(let roundIndex, let participants):
            syncParticipantStats(participants)
            let summary = RoundSummary(
                roundIndex: roundIndex,
                problems: currentRoom?.roundProblems ?? [],
                answers: currentRoom?.roundAnswers ?? [],
                players: currentRoom?.players ?? []
            )
            lastRoundSummary = summary
            currentRoom?.currentRoundIndex = roundIndex + 1
            currentRoom?.roundAnswers = []

        case .turnTimeFactor(let userId, _, let totalScore):
            if let idx = currentRoom?.players.firstIndex(where: { $0.id == userId }) {
                currentRoom?.players[idx].score = totalScore
            }

        case .error:
            break
        }
    }

    /// Apply a full room state received from the server.
    private func applyRoomState(_ state: WSRoomState) {
        guard var room = currentRoom else { return }
        room.currentTurnIndex = {
            // Convert backend turnIndex (into participants array) to activePlayers index
            let active = room.activePlayers
            let current = state.participants[safe: state.turnIndex]
            return active.firstIndex(where: { $0.id == current?.userId }) ?? 0
        }()
        room.questionsPerTurn = state.questionsPerRound ?? room.questionsPerTurn
        if let name = state.name, !name.isEmpty { room.customName = name }
        if let roundIdx = state.currentRoundIndex { room.currentRoundIndex = roundIdx }
        syncParticipantStats(state.participants, in: &room)
        currentRoom = room
    }

    /// Update local player stats from server's participant list.
    private func syncParticipantStats(_ participants: [WSParticipant]) {
        guard var room = currentRoom else { return }
        syncParticipantStats(participants, in: &room)
        currentRoom = room
    }

    private func syncParticipantStats(_ participants: [WSParticipant], in room: inout MultiplayerRoom) {
        for p in participants {
            if let idx = room.players.firstIndex(where: { $0.id == p.userId }) {
                room.players[idx].lives = p.lives
                room.players[idx].skips = p.skips
                room.players[idx].score = p.score
                room.players[idx].isEliminated = !p.isActive
            }
        }
    }

    var pendingInviteCount: Int { pendingInvites.count }

    /// Accept a pending invite and join the room via the backend.
    func acceptInvite(_ invite: MultiplayerInvite, ownUsername: String) {
        pendingInvites.removeAll { $0.id == invite.id }
        Task {
            try await joinRealRoom(code: invite.roomCode, ownUsername: ownUsername)
        }
    }

    func declineInvite(_ invite: MultiplayerInvite) {
        pendingInvites.removeAll { $0.id == invite.id }
    }
    @Published var recentActivity: [MultiplayerActivityItem] = [] { didSet { persistRecentActivity() } }
    @Published var lastGameEvent: GameEvent?
    @Published var lastRoundSummary: RoundSummary? = nil

    struct RoundSummary {
        let roundIndex: Int
        let problems: [SharedProblem]
        let answers: [RoundAnswer]
        let players: [MultiplayerPlayer]
    }

    private var wsObserveTask: Task<Void, Never>?

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

    /// Creates a local room object without a backend room (used internally by createRealRoom).
    private func createLocalRoom(mode: GameMode, ownUsername: String, roomCode: String,
                                 name: String = "", questionsPerRound: Int = 3,
                                 invitedUsername: String? = nil) {
        var host = MultiplayerPlayer(id: "me", username: ownUsername, isHost: true, isReady: true, isYou: true)
        applyOwnStats(to: &host)
        var room = MultiplayerRoom(id: roomCode, mode: mode, startLevel: 1, players: [host], status: .lobby)
        room.customName = name
        room.questionsPerTurn = questionsPerRound
        currentRoom = room
        if let invited = invitedUsername {
            inviteFriend(username: invited, playerID: "pending_\(invited)")
        }
    }

    func inviteFriend(username: String, playerID: String) {
        guard currentRoom != nil else { return }
        guard !(currentRoom?.players.contains(where: { $0.username == username }) ?? false) else { return }
        if !(currentRoom?.invitedUsernames.contains(username) ?? false) {
            currentRoom?.invitedUsernames.append(username)
        }
        let player = MultiplayerPlayer(id: playerID, username: username, isHost: false, isReady: false)
        currentRoom?.players.append(player)
        if let roomId = backendRoomId {
            Task {
                struct Body: Encodable { let username: String }
                _ = try? await APIClient.shared.post("ws/rooms/\(roomId)/invite", body: Body(username: username)) as Empty
            }
        }
    }

    /// Snapshot the local user's progression stats onto the player record.
    private func applyOwnStats(to player: inout MultiplayerPlayer) {
        let p = ProgressionStore.shared
        player.piLevel       = p.piLevel
        player.mathLevel     = p.mathLevel
        player.chemLevel     = p.chemLevel
        player.geoLevel      = p.geoLevel
        player.brainLevel    = p.brainLevel
        player.scienceLevel  = p.scienceLevel
        player.historyLevel  = p.historyLevel
        player.physicsLevel  = p.physicsLevel
        player.sportLevel    = p.sportLevel
        player.grammarLevel  = p.grammarLevel
        player.piBestScore   = p.piBestScore
        player.mathBestScore = p.mathBestScore
        player.chemBestScore = p.chemBestScore
        player.geoBestScore  = p.geoBestScore
        player.brainBestScore = p.brainBestScore
        player.scienceBestScore = p.scienceBestScore
        player.historyBestScore = p.historyBestScore
        player.physicsBestScore = p.physicsBestScore
        player.sportBestScore   = p.sportBestScore
        player.grammarBestScore = p.grammarBestScore
    }

    func toggleReady() {
        guard let idx = currentRoom?.players.firstIndex(where: { $0.isYou }) else { return }
        currentRoom?.players[idx].isReady.toggle()
    }

    var allReady: Bool { currentRoom?.players.allSatisfy(\.isReady) ?? false }

    func startGame() {
        guard let room = currentRoom else { return }
        let name = room.customName
        let qpr = room.questionsPerTurn

        // Drop invited players who haven't joined
        if var r = currentRoom {
            let dropped = r.players.filter { !$0.isHost && !$0.isReady && r.invitedUsernames.contains($0.username) }
            r.invitedUsernames = Array(Set(r.invitedUsernames + dropped.map(\.username)))
            r.players.removeAll { !$0.isHost && !$0.isReady }
            currentRoom = r
        }

        if backendRoomId != nil {
            // Real room: send WS start_game with final settings
            let modeSlug = room.serverModeSlug ?? room.mode.slug
            wsClient.send(.startGame(name: name, questionsPerRound: qpr, mode: modeSlug))
        }

        // Optimistic local transition
        currentRoom?.status = .playing
        currentRoom?.currentTurnIndex = 0
        currentRoom?.currentTurnQuestionsAnswered = 0
        currentRoom?.currentQuestionIndex = 0
        currentRoom?.currentRoundIndex = 1
        currentRoom?.roundAnswers = []
        seedRoundProblems()
    }

    func dismissRoundSummary() {
        lastRoundSummary = nil
    }

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
        if room.status == .playing {
            if !backgroundRooms.contains(where: { $0.id == room.id }) {
                backgroundRooms.append(room)
            }
            scheduleGameReminderNotification(delay: room.isMyTurn ? 1 : 30)
        }
        // Keep WS alive briefly then disconnect
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            wsClient.disconnect()
        }
        currentRoom = nil
    }

    func rejoin(roomID: String) {
        cancelGameReminderNotification()
        if let idx = backgroundRooms.firstIndex(where: { $0.id == roomID }) {
            currentRoom = backgroundRooms.remove(at: idx)
            // Reconnect WS if we have the backend room ID
            if let roomId = backendRoomId {
                wsClient.connect(roomId: roomId)
                observeWS()
            }
        }
    }

    func leaveRoom() {
        wsObserveTask?.cancel()
        wsObserveTask = nil
        cancelGameReminderNotification()
        if let id = currentRoom?.id {
            backgroundRooms.removeAll { $0.id == id }
        }
        wsClient.disconnect()
        currentRoom = nil
        backendRoomId = nil
    }

    func leaveBackgroundRoom(id: String) {
        backgroundRooms.removeAll { $0.id == id }
    }

    // MARK: – Standalone solo (Pi/Math/etc.) sessions

    private func removeExistingStandaloneSave(mode: GameMode? = nil, serverSlug: String? = nil) {
        if let slug = serverSlug {
            backgroundRooms.removeAll { $0.isStandaloneSolo && $0.serverModeSlug == slug }
        } else if let m = mode {
            backgroundRooms.removeAll { $0.isStandaloneSolo && $0.mode == m && $0.serverModeSlug == nil }
        }
    }

    func saveStandaloneSoloPi(ownUsername: String,
                              lives: Int, skips: Int,
                              score: Int, correctCount: Int,
                              currentDigit: Int) -> String {
        let id = "SOLO-" + String(UUID().uuidString.prefix(4).uppercased())
        var player = MultiplayerPlayer(id: "me", username: ownUsername,
                                       isHost: true, isReady: true, isYou: true)
        player.lives = lives; player.skips = skips
        player.score = score; player.correctCount = correctCount
        var room = MultiplayerRoom(id: id, mode: .pi, startLevel: 1,
                                   players: [player], status: .playing)
        room.myPiDigitIndex = currentDigit
        room.isStandaloneSolo = true
        room.lastActivityAt = Date()
        removeExistingStandaloneSave(mode: .pi)
        backgroundRooms.append(room)
        return id
    }

    func saveStandaloneSoloGeo(ownUsername: String,
                               lives: Int, skips: Int,
                               score: Int, correctCount: Int,
                               startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .geography, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloChem(ownUsername: String,
                                lives: Int, skips: Int,
                                score: Int, correctCount: Int,
                                startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .chemistry, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloBrainTraining(ownUsername: String,
                                         lives: Int, skips: Int,
                                         score: Int, correctCount: Int,
                                         startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .brainTraining, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloScience(ownUsername: String,
                                   lives: Int, skips: Int,
                                   score: Int, correctCount: Int,
                                   startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .science, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloHistory(ownUsername: String,
                                   lives: Int, skips: Int,
                                   score: Int, correctCount: Int,
                                   startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .history, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloPhysics(ownUsername: String,
                                   lives: Int, skips: Int,
                                   score: Int, correctCount: Int,
                                   startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .physics, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloSport(ownUsername: String,
                                 lives: Int, skips: Int,
                                 score: Int, correctCount: Int,
                                 startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .sport, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSolo(mode: GameMode, ownUsername: String,
                            lives: Int, skips: Int,
                            score: Int, correctCount: Int,
                            startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: mode, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    private func saveStandaloneSoloFeature(mode: GameMode, ownUsername: String,
                                           lives: Int, skips: Int,
                                           score: Int, correctCount: Int,
                                           startLevel: Int) -> String {
        let id = "SOLO-" + String(UUID().uuidString.prefix(4).uppercased())
        var player = MultiplayerPlayer(id: "me", username: ownUsername,
                                       isHost: true, isReady: true, isYou: true)
        player.lives = lives; player.skips = skips
        player.score = score; player.correctCount = correctCount
        var room = MultiplayerRoom(id: id, mode: mode, startLevel: startLevel,
                                   players: [player], status: .playing)
        room.isStandaloneSolo = true
        room.lastActivityAt = Date()
        removeExistingStandaloneSave(mode: mode)
        backgroundRooms.append(room)
        return id
    }

    func saveStandaloneSoloGrammar(ownUsername: String,
                                   lives: Int, skips: Int,
                                   score: Int, correctCount: Int,
                                   startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .grammar, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func saveStandaloneSoloKnowledge(slug: String, name: String, ownUsername: String,
                                      lives: Int, skips: Int,
                                      score: Int, correctCount: Int,
                                      startLevel: Int) -> String {
        let id = "SOLO-" + String(UUID().uuidString.prefix(4).uppercased())
        var player = MultiplayerPlayer(id: "me", username: ownUsername,
                                       isHost: true, isReady: true, isYou: true)
        player.lives = lives; player.skips = skips
        player.score = score; player.correctCount = correctCount
        var room = MultiplayerRoom(id: id, mode: .pi, startLevel: startLevel,
                                   players: [player], status: .playing)
        room.serverModeSlug = slug
        room.serverModeName = name
        room.isStandaloneSolo = true
        room.lastActivityAt = Date()
        removeExistingStandaloneSave(serverSlug: slug)
        backgroundRooms.append(room)
        return id
    }

    func saveStandaloneSoloMath(ownUsername: String,
                                lives: Int, skips: Int,
                                score: Int, correctCount: Int,
                                startLevel: Int) -> String {
        saveStandaloneSoloFeature(mode: .math, ownUsername: ownUsername,
                                  lives: lives, skips: skips, score: score,
                                  correctCount: correctCount, startLevel: startLevel)
    }

    func popStandaloneSolo(roomID: String) -> MultiplayerRoom? {
        guard let idx = backgroundRooms.firstIndex(where: { $0.id == roomID && $0.isStandaloneSolo })
        else { return nil }
        return backgroundRooms.remove(at: idx)
    }

    func popStandaloneSoloByMode(_ mode: GameMode) -> MultiplayerRoom? {
        guard let idx = backgroundRooms.firstIndex(where: {
            $0.isStandaloneSolo && $0.mode == mode && $0.serverModeSlug == nil
        }) else { return nil }
        return backgroundRooms.remove(at: idx)
    }

    // MARK: – Gameplay

    func submitAnswer(correct: Bool, answerTime: Double) {
        guard var room = currentRoom, room.isMyTurn else { return }
        ProgressionStore.shared.consumeQuestion()

        let playerIdx = room.players.firstIndex(where: { $0.isYou }) ?? 0
        recordRoundAnswer(to: &room, playerIdx: playerIdx,
                          correct: correct, skipped: false, answerTime: answerTime)

        // Optimistic local update
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
        advanceQuestionOrTurn(&room)
        currentRoom = room

        // Send to backend — server drives turn changes
        wsClient.send(.submitAnswer(
            questionRef: piQuestionRef(room: room),
            userAnswer: correct ? "1" : "0",
            answerTimeMs: Int(max(200, answerTime * 1000)),
            clientReportsCorrect: correct
        ))

        if room.status == .finished { recordActivity(room) }
    }

    /// For Pi mode: the absolute digit index is the question reference the server validates.
    private func piQuestionRef(room: MultiplayerRoom) -> String {
        if room.mode == .pi {
            return "\(room.myPiDigitIndex + room.currentTurnQuestionsAnswered)"
        }
        return ""
    }

    func useSkip() {
        guard var room = currentRoom, room.isMyTurn else { return }
        ProgressionStore.shared.consumeQuestion()
        guard let idx = room.players.firstIndex(where: { $0.isYou }) else { return }
        recordRoundAnswer(to: &room, playerIdx: idx, correct: false, skipped: true, answerTime: nil)
        room.players[idx].skips = max(0, room.players[idx].skips - 1)
        if room.players[idx].skips == 0 { room.players[idx].isEliminated = true }
        advanceQuestionOrTurn(&room)
        currentRoom = room

        wsClient.send(.useSkip)

        if room.status == .finished { recordActivity(room) }
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

    private func advanceTurn(_ room: inout MultiplayerRoom) {
        let active = room.activePlayers
        let isMultiplayer = room.players.count > 1
        if active.isEmpty || (isMultiplayer && active.count == 1) {
            room.status = .finished
            return
        }
        room.currentTurnIndex = (room.currentTurnIndex + 1) % max(1, active.count)
    }

    private func advanceQuestionOrTurn(_ room: inout MultiplayerRoom) {
        room.currentTurnQuestionsAnswered += 1
        let perTurn = max(1, room.questionsPerTurn)
        if room.currentTurnQuestionsAnswered < perTurn && !(room.currentPlayer?.isEliminated ?? false) {
            room.currentQuestionIndex = room.currentTurnQuestionsAnswered
            return
        }
        let prevTurnIndex = room.currentTurnIndex
        advanceTurn(&room)
        room.currentTurnQuestionsAnswered = 0
        room.currentQuestionIndex = 0

        guard room.status == .playing else { return }

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
            if let updated = currentRoom { room = updated }
        }
    }

    private func recordRoundAnswer(to room: inout MultiplayerRoom, playerIdx: Int, correct: Bool, skipped: Bool, answerTime: Double?) {
        guard playerIdx >= 0, playerIdx < room.players.count else { return }
        let player = room.players[playerIdx]
        let qIndex = min(room.currentTurnQuestionsAnswered, max(0, room.questionsPerTurn - 1))
        let prompt = qIndex < room.roundProblems.count ? room.roundProblems[qIndex].prompt : ""
        room.roundAnswers.append(RoundAnswer(
            playerID: player.id,
            username: player.username,
            questionInRound: qIndex,
            correct: correct,
            skipped: skipped,
            problemPrompt: prompt,
            answerTime: answerTime
        ))
    }

    private func recordActivity(_ room: MultiplayerRoom) {
        guard let me = room.players.first(where: { $0.isYou }) else { return }
        let opponent = room.players.first(where: { !$0.isYou })
        let item = MultiplayerActivityItem(
            opponentUsername: opponent?.username ?? "–",
            mode: room.mode,
            didWin: room.winner?.isYou == true,
            score: me.score,
            timestamp: Date(),
            roomId: room.id
        )
        recentActivity.insert(item, at: 0)
        if recentActivity.count > 10 { recentActivity = Array(recentActivity.prefix(10)) }
        ProgressionStore.shared.recordMultiplayerScore(mode: room.mode, score: me.score, correctCount: me.correctCount)
    }

    @MainActor func setTauntOnLatestActivity(_ taunt: String) {
        guard !recentActivity.isEmpty else { return }
        recentActivity[0].winnerTaunt = taunt
    }
}

// MARK: – Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

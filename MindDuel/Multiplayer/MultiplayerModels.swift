import SwiftUI

struct GameEvent: Identifiable {
    let id = UUID()
    let message: String
    let isPositive: Bool
}

/// A pending invite to a multiplayer room (#56). The "Bli med" entry point
/// on the home screen now lists these so the user can pick which one to join.
struct MultiplayerInvite: Identifiable, Codable {
    var id = UUID()
    let roomCode: String
    let mode: GameMode
    let hostUsername: String
    let invitedAt: Date
}

struct MultiplayerActivityItem: Identifiable, Codable {
    var id = UUID()
    let opponentUsername: String
    let mode: GameMode
    let didWin: Bool
    let score: Int
    let timestamp: Date

    var timeAgoString: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 60 { return String(localized: "time_just_now") }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)t" }
        return "\(hours / 24)d"
    }
}

struct MultiplayerPlayer: Identifiable, Equatable, Codable {
    let id: String
    let username: String
    var isHost: Bool
    var isReady: Bool
    var lives: Int = 5
    var skips: Int = 5
    var score: Int = 0
    var correctCount: Int = 0
    var isEliminated: Bool = false
    var isYou: Bool = false
    /// Lobby stats shown next to each player (issue #21). Mode-dependent —
    /// the lobby renders piLevel/piBestScore for Pi rooms and math counterparts
    /// for Math rooms. Defaults keep saved-room decoding stable.
    var piLevel: Int = 1
    var mathLevel: Int = 1
    var chemLevel: Int = 1
    var geoLevel: Int = 1
    var brainLevel: Int = 1
    var piBestScore: Int = 0
    var mathBestScore: Int = 0
    var chemBestScore: Int = 0
    var geoBestScore: Int = 0
    var brainBestScore: Int = 0
}

enum RoomStatus: String, Codable { case lobby, playing, finished }

/// #93/#96: a problem generated once per round and shared across all
/// players. Stored on the room so every player sees identical questions
/// and the round-summary view (#96) can render historical prompts.
struct SharedProblem: Codable, Identifiable {
    var id = UUID()
    let mode: GameMode
    let prompt: String
    /// Flag emoji rendered above the prompt for geography questions.
    let flag: String?
    let options: [String]
    let correctIndex: Int
    /// Curriculum / context label rendered between header and prompt.
    let curriculumLabel: String?

    var correctAnswer: String { options[correctIndex] }
}

/// #96: one answer logged for the round-summary screen so every player
/// can see how the others fared.
struct RoundAnswer: Codable, Identifiable {
    var id = UUID()
    let playerID: String
    let username: String
    let questionInRound: Int
    let correct: Bool
    let skipped: Bool
    /// Snapshot of the prompt so the summary remains readable even after
    /// `roundProblems` flips to the next batch.
    let problemPrompt: String
}

struct MultiplayerRoom: Identifiable, Codable {
    let id: String          // room code, e.g. "4F2A"
    var mode: GameMode
    /// Optional human-readable name set by the host (#83). When empty, UI
    /// falls back to the room code so older saved rooms keep working.
    var customName: String = ""
    /// Usernames of everyone the host invited, including those dropped at
    /// start because they never accepted (#109). Populated alongside
    /// `players` so we can still show participants on Active Games rows
    /// after the not-ready filter has run in `startGame`.
    var invitedUsernames: [String] = []
    /// Math difficulty level the room started at (1 – 20).
    /// Only meaningful for `mode == .math`; ignored for Pi (Pi uses
    /// `myPiDigitIndex` + the user's piLevel boundary). Default 1 keeps
    /// the on-disk format stable for existing saved rooms.
    var startLevel: Int = 1
    var players: [MultiplayerPlayer]
    var status: RoomStatus
    var currentTurnIndex: Int = 0
    /// Absolute Pi digit index this room is at (only used for `mode == .pi`).
    /// Saved on each correct answer so resume picks up at the same digit even
    /// if the user's piPosition shifted in another session.
    var myPiDigitIndex: Int = 0
    /// True for single-player Pi/Math sessions saved from PiGameView /
    /// MathGameView; false for multiplayer rooms (incl. solo-of-multiplayer).
    /// Routing in HomeView/ActiveGamesView uses this to pick which view to
    /// resume in.
    var isStandaloneSolo: Bool = false
    /// When the room last saw activity (turn submitted, skip, save, …).
    /// Surfaced on ActiveGamesView rows (#49) so players can decide whether
    /// to discard a stale game. Defaults to creation time.
    var lastActivityAt: Date = Date()
    /// #95: how many questions each player must answer before their turn
    /// hands off to the next player. Default 1 = original "1 question, 1
    /// pass" behavior.
    var questionsPerTurn: Int = 1
    /// #95: how many questions the current player has answered this turn.
    /// Resets to 0 when control passes to the next player.
    var currentTurnQuestionsAnswered: Int = 0
    /// #93: shared problem set for the current round, generated once on the
    /// host and stored here so every player sees identical questions.
    var roundProblems: [SharedProblem] = []
    /// Index of the problem the current player is working through inside
    /// `roundProblems`. Equal to currentTurnQuestionsAnswered for the active
    /// player; used by views to render the right prompt.
    var currentQuestionIndex: Int = 0
    /// #96: per-round answer log used to render the round-summary view.
    /// Cleared at the start of each new round.
    var roundAnswers: [RoundAnswer] = []
    /// Round number, starting at 1. Bumped after every full pass through
    /// the active players.
    var currentRoundIndex: Int = 1

    var activePlayers: [MultiplayerPlayer] { players.filter { !$0.isEliminated } }

    var currentPlayer: MultiplayerPlayer? {
        let active = activePlayers
        guard !active.isEmpty else { return nil }
        return active[currentTurnIndex % active.count]
    }

    var isMyTurn: Bool { currentPlayer?.isYou ?? false }

    var winner: MultiplayerPlayer? {
        guard players.count > 1 else { return nil }  // solo game has no winner
        let active = activePlayers
        return active.count == 1 ? active.first : nil
    }
}

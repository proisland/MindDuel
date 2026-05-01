import SwiftUI

struct GameEvent: Identifiable {
    let id = UUID()
    let message: String
    let isPositive: Bool
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
    var piBestScore: Int = 0
    var mathBestScore: Int = 0
}

enum RoomStatus: String, Codable { case lobby, playing, finished }

struct MultiplayerRoom: Identifiable, Codable {
    let id: String          // room code, e.g. "4F2A"
    var mode: GameMode
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

import SwiftUI

struct MultiplayerActivityItem: Identifiable {
    let id = UUID()
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

struct MultiplayerPlayer: Identifiable, Equatable {
    let id: String
    let username: String
    var isHost: Bool
    var isReady: Bool
    var lives: Int = 5
    var skips: Int = 5
    var score: Int = 0
    var isEliminated: Bool = false
    var isYou: Bool = false
}

enum RoomStatus { case lobby, playing, finished }

struct MultiplayerRoom: Identifiable {
    let id: String          // room code, e.g. "4F2A"
    var mode: GameMode
    var startLevel: Int     // 1 = from start
    var players: [MultiplayerPlayer]
    var status: RoomStatus
    var currentTurnIndex: Int = 0

    var activePlayers: [MultiplayerPlayer] { players.filter { !$0.isEliminated } }

    var currentPlayer: MultiplayerPlayer? {
        let active = activePlayers
        guard !active.isEmpty else { return nil }
        return active[currentTurnIndex % active.count]
    }

    var isMyTurn: Bool { currentPlayer?.isYou ?? false }

    var winner: MultiplayerPlayer? {
        let active = activePlayers
        return active.count == 1 ? active.first : nil
    }
}

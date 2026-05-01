import XCTest
@testable import MindDuel

final class MindDuelTests: XCTestCase {

    func testUsernameValidation() {
        let valid = ["alice", "bob_99", "User123", "abc"]
        let invalid = ["ab", "", "a very long username that exceeds twenty", "user name", "user@name"]

        for name in valid {
            XCTAssertTrue(isValidUsername(name), "\(name) should be valid")
        }
        for name in invalid {
            XCTAssertFalse(isValidUsername(name), "\(name) should be invalid")
        }
    }

    private func isValidUsername(_ username: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return (3...20).contains(username.count)
            && username.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

@MainActor
final class ProgressionStoreTests: XCTestCase {

    private static let testKeys = [
        "piPosition", "piBestScore",
        "mathLevel", "mathLevelProgress", "mathBestScore",
        "dailyUsed", "quotaResetEpoch",
        "totalRoundsPlayed", "isFlagged", "fastRoundCount"
    ]

    override func setUp() {
        super.setUp()
        Self.testKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    func testPiLevelFormula() {
        // Level 1 covers piPosition 0–49, level 2 covers 50–99, capped at 20.
        XCTAssertEqual(ProgressionStore.piLevel(forPosition: 0), 1)
        XCTAssertEqual(ProgressionStore.piLevel(forPosition: 49), 1)
        XCTAssertEqual(ProgressionStore.piLevel(forPosition: 50), 2)
        XCTAssertEqual(ProgressionStore.piLevel(forPosition: 950), 20)
        XCTAssertEqual(ProgressionStore.piLevel(forPosition: 99999), 20,
                       "piLevel must cap at 20")
        XCTAssertEqual(ProgressionStore.piLevel(forPosition: -5), 1,
                       "Negative inputs should be clamped to level 1, not crash")
    }

    func testPiScoreReturnsZeroOnInvalidInput() {
        let s = ProgressionStore.shared
        XCTAssertEqual(s.piScore(correctCount: 0, avgTime: 1.0), 0)
        XCTAssertEqual(s.piScore(correctCount: 5, avgTime: 0.0), 0,
                       "avgTime ≤ 0.2 is treated as suspicious / invalid")
        XCTAssertEqual(s.piScore(correctCount: 5, avgTime: 0.1), 0)
    }

    func testPiScoreScalesWithCountAndSpeed() {
        let s = ProgressionStore.shared
        let slow = s.piScore(correctCount: 5, avgTime: 2.0)
        let fast = s.piScore(correctCount: 5, avgTime: 1.0)
        XCTAssertGreaterThan(fast, slow, "Faster avg time should yield more points")

        let few  = s.piScore(correctCount: 1, avgTime: 1.0)
        let many = s.piScore(correctCount: 10, avgTime: 1.0)
        XCTAssertGreaterThan(many, few)
    }

    func testMathScoreScalesWithLevel() {
        let s = ProgressionStore.shared
        let lo = s.mathScore(correctCount: 5, level: 1, avgTime: 1.0)
        let hi = s.mathScore(correctCount: 5, level: 5, avgTime: 1.0)
        XCTAssertGreaterThan(hi, lo, "Higher level → higher score multiplier")
    }
}

@MainActor
final class MultiplayerRoomTests: XCTestCase {

    func testIsMyTurnAndCurrentPlayer() {
        let me  = MultiplayerPlayer(id: "me",  username: "me",  isHost: true,  isReady: true, isYou: true)
        let bot = MultiplayerPlayer(id: "bot", username: "bot", isHost: false, isReady: true)
        let room = MultiplayerRoom(id: "X", mode: .pi, startLevel: 1,
                                   players: [me, bot], status: .playing,
                                   currentTurnIndex: 0)
        XCTAssertTrue(room.isMyTurn)
        XCTAssertEqual(room.currentPlayer?.id, "me")
    }

    func testWinnerIsNilForSoloRoom() {
        let me = MultiplayerPlayer(id: "me", username: "me", isHost: true, isReady: true, isYou: true)
        let room = MultiplayerRoom(id: "X", mode: .pi, startLevel: 1,
                                   players: [me], status: .playing)
        XCTAssertNil(room.winner, "Solo rooms have no winner — they end on elimination only")
    }

    func testWinnerIsLastActiveInMultiplayer() {
        let me  = MultiplayerPlayer(id: "me",  username: "me",  isHost: true,  isReady: true, isYou: true)
        var bot = MultiplayerPlayer(id: "bot", username: "bot", isHost: false, isReady: true)
        bot.isEliminated = true
        let room = MultiplayerRoom(id: "X", mode: .pi, startLevel: 1,
                                   players: [me, bot], status: .playing)
        XCTAssertEqual(room.winner?.id, "me")
    }

    func testRoomCodableRoundTrip() throws {
        let me = MultiplayerPlayer(id: "me", username: "petter", isHost: true, isReady: true, isYou: true)
        var room = MultiplayerRoom(id: "ABCD", mode: .math, startLevel: 3,
                                   players: [me], status: .playing)
        room.myPiDigitIndex = 17
        room.isStandaloneSolo = true

        let data = try JSONEncoder().encode(room)
        let decoded = try JSONDecoder().decode(MultiplayerRoom.self, from: data)
        XCTAssertEqual(decoded.id, "ABCD")
        XCTAssertEqual(decoded.mode, .math)
        XCTAssertEqual(decoded.startLevel, 3)
        XCTAssertEqual(decoded.myPiDigitIndex, 17)
        XCTAssertTrue(decoded.isStandaloneSolo)
        XCTAssertEqual(decoded.players.count, 1)
        XCTAssertEqual(decoded.players[0].username, "petter")
    }
}


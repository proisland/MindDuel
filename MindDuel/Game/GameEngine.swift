import SwiftUI

enum GamePhase {
    case playing
    case waitingAfterSkip
    case roundOver(reason: RoundEndReason)
}

enum RoundEndReason {
    case noLives
    case noSkips
    case quit
}

@MainActor final class GameEngine: ObservableObject {
    @Published private(set) var lives: Int
    @Published private(set) var skips: Int
    @Published private(set) var phase: GamePhase = .playing
    @Published private(set) var correctCount: Int

    nonisolated init(lives: Int = 5, skips: Int = 5, correctCount: Int = 0) {
        _lives        = Published(initialValue: lives)
        _skips        = Published(initialValue: skips)
        _correctCount = Published(initialValue: correctCount)
        _phase        = Published(initialValue: .playing)
    }

    var isRoundOver: Bool {
        if case .roundOver = phase { return true }
        return false
    }

    var isWaitingAfterSkip: Bool {
        if case .waitingAfterSkip = phase { return true }
        return false
    }

    func recordCorrect() {
        correctCount += 1
    }

    func recordWrong() {
        lives = max(0, lives - 1)
        if lives == 0 {
            phase = .roundOver(reason: .noLives)
        }
    }

    func useSkip() {
        skips = max(0, skips - 1)
        if skips == 0 {
            phase = .roundOver(reason: .noSkips)
        } else {
            phase = .waitingAfterSkip
        }
    }

    func resumeAfterSkip() {
        guard case .waitingAfterSkip = phase else { return }
        phase = .playing
    }

    func quit() {
        phase = .roundOver(reason: .quit)
    }

    func restart() {
        lives = 5
        skips = 5
        correctCount = 0
        phase = .playing
    }

    /// Restore mid-session state when resuming a saved single-player game.
    func restoreState(lives: Int, skips: Int, correctCount: Int) {
        self.lives = max(0, lives)
        self.skips = max(0, skips)
        self.correctCount = max(0, correctCount)
        phase = self.lives == 0 ? .roundOver(reason: .noLives) : .playing
    }
}

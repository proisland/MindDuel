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
    @Published private(set) var lives = 5
    @Published private(set) var skips = 5
    @Published private(set) var phase: GamePhase = .playing
    @Published private(set) var correctCount = 0

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
}

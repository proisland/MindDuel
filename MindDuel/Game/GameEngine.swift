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
    static let initialLives = 5
    static let initialSkips = 5

    @Published private(set) var lives = initialLives
    @Published private(set) var skips = initialSkips
    @Published private(set) var phase: GamePhase = .playing
    @Published private(set) var correctCount = 0

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
        lives = Self.initialLives
        skips = Self.initialSkips
        correctCount = 0
        phase = .playing
    }
}

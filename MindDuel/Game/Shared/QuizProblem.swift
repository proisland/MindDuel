import Foundation

/// Shared multiple-choice problem used by History, Science, Sport, Grammar, and Physics modes.
struct QuizProblem: GameProblem {
    let prompt: String
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? { options.firstIndex(of: correctAnswer) }
}

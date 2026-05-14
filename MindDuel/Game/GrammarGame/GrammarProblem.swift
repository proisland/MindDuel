import Foundation

/// #39: a grammar multiple-choice problem. Same shape as the other modes
/// so the existing AnswerButton grid renders it directly.
struct GrammarProblem: GameProblem {
    let prompt: String
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? { options.firstIndex(of: correctAnswer) }
}

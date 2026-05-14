import Foundation

/// #98: a natural-science multiple-choice problem. Same shape as the
/// other modes so the existing AnswerButton grid renders it directly.
struct ScienceProblem: GameProblem {
    let prompt: String
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? { options.firstIndex(of: correctAnswer) }
}

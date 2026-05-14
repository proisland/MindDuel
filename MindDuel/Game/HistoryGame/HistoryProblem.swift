import Foundation

/// #59: a history multiple-choice problem. Same shape as other modes so
/// the existing AnswerButton grid renders it directly.
struct HistoryProblem: GameProblem {
    let prompt: String
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? { options.firstIndex(of: correctAnswer) }
}

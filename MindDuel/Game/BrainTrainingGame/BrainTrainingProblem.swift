import Foundation

/// #116: a brain-training puzzle. The same multiple-choice shape as the
/// other modes so the existing AnswerButton grid renders without a special
/// case.
struct BrainTrainingProblem {
    /// Plain-text prompt rendered in the question card. May contain a
    /// sequence ("2, 4, 8, 16, ?") or a question ("Hva er 25 % av 80?").
    let prompt: String
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? {
        options.firstIndex(of: correctAnswer)
    }
}

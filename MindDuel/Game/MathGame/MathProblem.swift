import Foundation

struct MathProblem {
    let display: String
    let correctAnswer: Int
    let options: [Int]

    var correctIndex: Int? {
        options.firstIndex(of: correctAnswer)
    }
}

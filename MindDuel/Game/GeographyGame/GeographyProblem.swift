import Foundation

struct GeographyProblem {
    let prompt: String
    let correctAnswer: String
    let options: [String]

    var correctIndex: Int? {
        options.firstIndex(of: correctAnswer)
    }
}

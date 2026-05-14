import Foundation

protocol GameProblem {
    var prompt: String { get }
    var options: [String] { get }
    var correctAnswer: String { get }
    var flag: String? { get }
}

extension GameProblem {
    var flag: String? { nil }
}

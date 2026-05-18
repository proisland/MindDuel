import Foundation

enum ScienceProblemGenerator {
    typealias Raw = QuizProblemGenerator.Raw
    static func generate(level: Int = 1) -> QuizProblem {
        QuizProblemGenerator.generate(slug: "science", bank: ScienceQuestionBank.questions(forLevel:), level: level)
    }
    static func resetRoundHistory() { QuizProblemGenerator.resetRoundHistory(slug: "science") }
    static func curriculumLabel(forLevel level: Int) -> String { QuizProblemGenerator.curriculumLabel(forLevel: level) }
}

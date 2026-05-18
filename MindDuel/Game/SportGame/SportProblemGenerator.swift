import Foundation

enum SportProblemGenerator {
    typealias Raw = QuizProblemGenerator.Raw
    static func generate(level: Int = 1) -> QuizProblem {
        QuizProblemGenerator.generate(slug: "sport", bank: SportQuestionBank.questions(forLevel:), level: level)
    }
    static func resetRoundHistory() { QuizProblemGenerator.resetRoundHistory(slug: "sport") }
    static func curriculumLabel(forLevel level: Int) -> String { QuizProblemGenerator.curriculumLabel(forLevel: level) }
}

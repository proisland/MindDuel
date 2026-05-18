import Foundation

enum HistoryProblemGenerator {
    typealias Raw = QuizProblemGenerator.Raw
    static func generate(level: Int = 1) -> QuizProblem {
        QuizProblemGenerator.generate(slug: "history", bank: HistoryQuestionBank.questions(forLevel:), level: level)
    }
    static func resetRoundHistory() { QuizProblemGenerator.resetRoundHistory(slug: "history") }
    static func curriculumLabel(forLevel level: Int) -> String { QuizProblemGenerator.curriculumLabel(forLevel: level) }
}

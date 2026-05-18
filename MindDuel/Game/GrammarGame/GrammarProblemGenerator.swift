import Foundation

enum GrammarProblemGenerator {
    typealias Raw = QuizProblemGenerator.Raw
    static func generate(level: Int = 1) -> QuizProblem {
        QuizProblemGenerator.generate(slug: "grammar", bank: GrammarQuestionBank.questions(forLevel:), level: level)
    }
    static func resetRoundHistory() { QuizProblemGenerator.resetRoundHistory(slug: "grammar") }
    static func curriculumLabel(forLevel level: Int) -> String { QuizProblemGenerator.curriculumLabel(forLevel: level) }
}

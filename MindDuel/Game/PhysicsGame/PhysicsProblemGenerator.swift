import Foundation

enum PhysicsProblemGenerator {
    typealias Raw = QuizProblemGenerator.Raw
    static func generate(level: Int = 1) -> QuizProblem {
        QuizProblemGenerator.generate(slug: "physics", bank: PhysicsQuestionBank.questions(forLevel:), level: level)
    }
    static func resetRoundHistory() { QuizProblemGenerator.resetRoundHistory(slug: "physics") }
    static func curriculumLabel(forLevel level: Int) -> String { QuizProblemGenerator.curriculumLabel(forLevel: level) }
}

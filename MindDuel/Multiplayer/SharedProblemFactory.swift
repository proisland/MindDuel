import Foundation

/// #93: builds a list of `SharedProblem`s for the current round so every
/// player in the room can be served identical questions. Today the local
/// generators aren't seedable, so this just generates and snapshots the
/// problems on the host once per round; mock bots and remote players will
/// read the same snapshot from the room.
enum SharedProblemFactory {
    private static func quizBank(for mode: GameMode) -> (Int) -> [QuizProblemGenerator.Raw] {
        switch mode {
        case .science:  return ScienceQuestionBank.questions(forLevel:)
        case .history:  return HistoryQuestionBank.questions(forLevel:)
        case .physics:  return PhysicsQuestionBank.questions(forLevel:)
        case .sport:    return SportQuestionBank.questions(forLevel:)
        case .grammar:  return GrammarQuestionBank.questions(forLevel:)
        default:        return { _ in [] }
        }
    }

    static func makeRound(mode: GameMode, level: Int, count: Int,
                          piStartIndex: Int = 0) -> [SharedProblem] {
        (0..<max(1, count)).map { offset in
            switch mode {
            case .pi:
                let absIndex = piStartIndex + offset
                let target = PiData.digits[absIndex]
                let options = (0...9).map(String.init)
                return SharedProblem(
                    mode: .pi,
                    prompt: "\(absIndex + 1)",
                    flag: nil,
                    options: options,
                    correctIndex: target,
                    curriculumLabel: nil
                )
            case .math:
                let p = MathProblemGenerator.generate(level: level)
                return SharedProblem(
                    mode: .math,
                    prompt: p.display,
                    flag: nil,
                    options: p.options.map { "\($0)" },
                    correctIndex: p.correctIndex ?? 0,
                    curriculumLabel: MathProblemGenerator.curriculumLabel(forLevel: level)
                )
            case .chemistry:
                let p = ChemistryProblemGenerator.generate(level: level)
                return SharedProblem(
                    mode: .chemistry,
                    prompt: p.prompt,
                    flag: nil,
                    options: p.options,
                    correctIndex: p.correctIndex ?? 0,
                    curriculumLabel: ChemistryProblemGenerator.curriculumLabel(forLevel: level)
                )
            case .geography:
                let p = GeographyProblemGenerator.generate(level: level)
                return SharedProblem(
                    mode: .geography,
                    prompt: p.prompt,
                    flag: p.flag,
                    options: p.options,
                    correctIndex: p.correctIndex ?? 0,
                    curriculumLabel: GeographyProblemGenerator.curriculumLabel(forLevel: level)
                )
            case .brainTraining:
                let p = BrainTrainingProblemGenerator.generate(level: level)
                return SharedProblem(
                    mode: .brainTraining,
                    prompt: p.prompt,
                    flag: nil,
                    options: p.options,
                    correctIndex: p.correctIndex ?? 0,
                    curriculumLabel: BrainTrainingProblemGenerator.curriculumLabel(forLevel: level)
                )
            case .science, .history, .physics, .sport, .grammar:
                let bank = quizBank(for: mode)
                let p = QuizProblemGenerator.generate(slug: mode.slug, bank: bank, level: level)
                return SharedProblem(
                    mode: mode,
                    prompt: p.prompt,
                    flag: nil,
                    options: p.options,
                    correctIndex: p.correctIndex ?? 0,
                    curriculumLabel: QuizProblemGenerator.curriculumLabel(forLevel: level)
                )
            }
        }
    }
}

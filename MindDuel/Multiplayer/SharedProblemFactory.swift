import Foundation

/// #93: builds a list of `SharedProblem`s for the current round so every
/// player in the room can be served identical questions. Today the local
/// generators aren't seedable, so this just generates and snapshots the
/// problems on the host once per round; mock bots and remote players will
/// read the same snapshot from the room.
enum SharedProblemFactory {
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
            }
        }
    }
}

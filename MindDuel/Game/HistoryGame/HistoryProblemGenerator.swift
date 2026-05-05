import Foundation

/// #59: history problem generator. Each level (1–20) ships ≥50 curated
/// questions covering Norge + verden, oldtid → moderne tid. LK20-aligned
/// where possible. Round history avoids repeats within a session.
enum HistoryProblemGenerator {

    private static var seenCorrects: Set<String> = []

    static func resetRoundHistory() { seenCorrects.removeAll() }

    static func generate(level: Int = 1) -> HistoryProblem {
        let clamped = max(1, min(20, level))
        let pool = HistoryQuestionBank.questions(forLevel: clamped)
        var candidates = pool.filter { !seenCorrects.contains($0.correct + ":" + $0.prompt) }
        if candidates.isEmpty {
            seenCorrects.subtract(pool.map { $0.correct + ":" + $0.prompt })
            candidates = pool
        }
        let raw = candidates.randomElement() ?? pool[0]
        seenCorrects.insert(raw.correct + ":" + raw.prompt)
        let opts = ([raw.correct] + Array(raw.distractors.shuffled().prefix(3))).shuffled()
        return HistoryProblem(prompt: raw.prompt,
                              correctAnswer: raw.correct,
                              options: opts)
    }

    static func curriculumLabel(forLevel level: Int) -> String {
        let l = max(1, min(20, level))
        if l <= 10 {
            return String(format: String(localized: "curriculum_grade_format"), l)
        } else if l <= 13 {
            return String(format: String(localized: "curriculum_vgs_format"), l - 10)
        } else {
            return String(format: String(localized: "curriculum_university_format"), l - 13)
        }
    }

    struct Raw {
        let prompt: String
        let correct: String
        let distractors: [String]
    }
}

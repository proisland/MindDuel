import Foundation

/// #67: sport problem generator. Each level (1–20) ships ≥50 curated
/// questions covering populære sporter, regler, kjente utøvere, OL og
/// VM-historie. Round history avoids repeats within a session.
enum SportProblemGenerator {

    private static let historyMode = "sport"
    private static var seenCorrects: Set<String> = QuestionHistory.load(mode: "sport")

    static func resetRoundHistory() { seenCorrects = QuestionHistory.load(mode: historyMode) }

    static func generate(level: Int = 1) -> SportProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(forLevel: clamped)
        var candidates = pool.filter { !seenCorrects.contains($0.correct + ":" + $0.prompt) }
        if candidates.isEmpty {
            let poolKeys = Set(pool.map { $0.correct + ":" + $0.prompt })
            seenCorrects.subtract(poolKeys)
            QuestionHistory.removeKeys(poolKeys, mode: historyMode)
            candidates = pool
        }
        let raw = candidates.randomElement() ?? pool[0]
        let key = raw.correct + ":" + raw.prompt
        seenCorrects.insert(key)
        QuestionHistory.save(seenCorrects, mode: historyMode)
        let opts = ([raw.correct] + Array(raw.distractors.shuffled().prefix(3))).shuffled()
        return SportProblem(prompt: raw.prompt,
                            correctAnswer: raw.correct,
                            options: opts)
    }

    private static func pool(forLevel level: Int) -> [Raw] {
        if let cached = QuestionPackCache.shared.questions(for: "sport") {
            let filtered = cached.filter { $0.level == level }
            if !filtered.isEmpty {
                return filtered.map { q in
                    Raw(prompt: q.prompt, correct: q.answer,
                        distractors: q.options.filter { $0 != q.answer })
                }
            }
        }
        return SportQuestionBank.questions(forLevel: level)
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

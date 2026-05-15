import Foundation

/// #98: natural-science problem generator. Each level (1–20) ships a
/// curated pool of 50+ questions covering biology, physics, chemistry,
/// astronomy and geology — calibrated to LK20 progression where possible.
/// Pulls from the level's pool with no-repeat round history (matches
/// GeographyProblemGenerator's contract).
enum ScienceProblemGenerator {

    private static let historyMode = "science"
    private static var seenCorrects: Set<String> = QuestionHistory.load(mode: "science")

    static func resetRoundHistory() { seenCorrects = QuestionHistory.load(mode: historyMode) }

    static func generate(level: Int = 1) -> ScienceProblem {
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
        return ScienceProblem(prompt: raw.prompt,
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

    private static func pool(forLevel level: Int) -> [Raw] {
        if let cached = QuestionPackCache.shared.questions(for: "science") {
            let filtered = cached.filter { $0.level == level }
            if !filtered.isEmpty {
                return filtered.map { q in
                    Raw(prompt: q.prompt, correct: q.answer,
                        distractors: q.options.filter { $0 != q.answer })
                }
            }
        }
        return ScienceQuestionBank.questions(forLevel: level)
    }
}

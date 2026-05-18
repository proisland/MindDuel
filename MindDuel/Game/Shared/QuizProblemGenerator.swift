import Foundation

/// Shared generator for History, Science, Sport, Grammar, and Physics modes.
/// Each mode passes its backend slug and local question-bank fallback.
/// Uses QuestionPackCache first; falls back to the local bank when the cache
/// has no questions for the requested level.
enum QuizProblemGenerator {

    struct Raw {
        let prompt: String
        let correct: String
        let distractors: [String]
    }

    private static var seenCorrectsBySlug: [String: Set<String>] = [:]

    private static func seenCorrects(for slug: String) -> Set<String> {
        if let existing = seenCorrectsBySlug[slug] { return existing }
        let loaded = QuestionHistory.load(mode: slug)
        seenCorrectsBySlug[slug] = loaded
        return loaded
    }

    static func resetRoundHistory(slug: String) {
        seenCorrectsBySlug[slug] = QuestionHistory.load(mode: slug)
    }

    static func generate(slug: String, bank: (Int) -> [Raw], level: Int = 1) -> QuizProblem {
        let clamped = max(1, min(20, level))
        let pool = pool(slug: slug, bank: bank, level: clamped)
        var seen = seenCorrects(for: slug)
        var candidates = pool.filter { !seen.contains($0.correct + ":" + $0.prompt) }
        if candidates.isEmpty {
            let poolKeys = Set(pool.map { $0.correct + ":" + $0.prompt })
            seen.subtract(poolKeys)
            QuestionHistory.removeKeys(poolKeys, mode: slug)
            candidates = pool
        }
        let raw = candidates.randomElement() ?? pool[0]
        let key = raw.correct + ":" + raw.prompt
        seen.insert(key)
        seenCorrectsBySlug[slug] = seen
        QuestionHistory.save(seen, mode: slug)
        let opts = ([raw.correct] + Array(raw.distractors.shuffled().prefix(3))).shuffled()
        return QuizProblem(prompt: raw.prompt, correctAnswer: raw.correct, options: opts)
    }

    private static func pool(slug: String, bank: (Int) -> [Raw], level: Int) -> [Raw] {
        if let cached = QuestionPackCache.shared.questions(for: slug) {
            let filtered = cached.filter { $0.level == level }
            if !filtered.isEmpty {
                return filtered.map { q in
                    Raw(prompt: q.prompt, correct: q.answer,
                        distractors: q.options.filter { $0 != q.answer })
                }
            }
        }
        return bank(level)
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
}

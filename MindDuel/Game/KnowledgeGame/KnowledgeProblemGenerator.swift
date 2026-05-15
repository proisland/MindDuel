import Foundation

/// Picks questions from a cached question pack, mirroring the pattern used by
/// the other *ProblemGenerator types. The seen-correct set is stored here
/// (not in the view) so KnowledgeGameView stays free of seen-ID state.
///
/// Unlike chemistry/math generators (which mark every shown question as seen),
/// this one only marks *correctly answered* questions — allowing the player
/// to retry questions they got wrong within the same round. The seen set is
/// persisted to disk so correctly-answered questions are skipped across rounds.
enum KnowledgeProblemGenerator {

    /// Per-slug set of question IDs the player answered correctly, persisted
    /// across rounds via QuestionHistory.
    private static var seenCorrects: [String: Set<String>] = [:]

    /// Reloads persisted history for a slug at round start instead of clearing,
    /// so cross-round deduplication is maintained.
    static func resetRoundHistory(slug: String) {
        seenCorrects[slug] = QuestionHistory.load(mode: slug)
    }

    /// Records that the player answered a question correctly and persists it
    /// so the question won't repeat in future rounds.
    static func recordCorrect(slug: String, questionId: String) {
        seenCorrects[slug, default: []].insert(questionId)
        QuestionHistory.save(seenCorrects[slug] ?? [], mode: slug)
    }

    /// Picks the next question for a slug/level, avoiding correctly-answered
    /// questions unless the entire eligible pool has been exhausted.
    static func generate(slug: String, level: Int) -> APIQuestion? {
        let all     = QuestionPackCache.shared.questions(for: slug) ?? []
        let atLevel = all.filter { $0.level == level }
        let pool    = atLevel.isEmpty ? all : atLevel
        guard !pool.isEmpty else { return nil }

        let seen     = seenCorrects[slug] ?? []
        let eligible = pool.filter { !seen.contains($0.id) }
        if eligible.isEmpty {
            // All questions exhausted — reset history for this slug and start fresh
            seenCorrects[slug] = []
            QuestionHistory.save([], mode: slug)
        }
        let source = eligible.isEmpty ? pool : eligible
        return source.randomElement()?.shufflingOptions()
    }
}

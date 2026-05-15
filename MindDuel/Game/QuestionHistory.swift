import Foundation

/// Persists question-seen keys to UserDefaults so correctly-answered (or
/// shown) questions are skipped across rounds and app restarts.
///
/// Keys are simple strings — for knowledge-pack modes the question's `id`
/// field is used; for procedural generators the key is `"correct:prompt"`.
/// Keyed by mode slug so each mode has its own independent history.
enum QuestionHistory {
    private static let defaults  = UserDefaults.standard
    private static let keyPrefix = "qhist_"

    static func load(mode: String) -> Set<String> {
        guard let data = defaults.data(forKey: keyPrefix + mode),
              let set  = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return [] }
        return set
    }

    static func save(_ set: Set<String>, mode: String) {
        guard let data = try? JSONEncoder().encode(set) else { return }
        defaults.set(data, forKey: keyPrefix + mode)
    }

    /// Removes a specific subset of keys from persistence (pool-exhaustion
    /// partial reset: clear only the exhausted level, not other levels).
    static func removeKeys(_ keys: Set<String>, mode: String) {
        var current = load(mode: mode)
        current.subtract(keys)
        save(current, mode: mode)
    }
}

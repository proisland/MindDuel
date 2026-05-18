import Foundation

/// Manages versioned question pack downloads. Packs are stored on disk so they
/// survive app restarts and work offline. The cache performs atomic swaps: the
/// new pack is fully written before the old one is replaced.
///
/// Packs are keyed by `{mode}_{language}` so Norwegian and English versions
/// coexist without evicting each other. The app language is detected once per
/// launch via `Bundle.main.preferredLocalizations.first` and normalised to a
/// two-letter code; English is the fallback when no supported code matches.
// Thread-safe in-memory cache for decoded question packs. Used by `nonisolated`
// methods that can be called from any thread during gameplay.
private final class MemoryCache: @unchecked Sendable {
    private var store: [String: [APIQuestion]] = [:]
    private let lock = NSLock()

    func get(_ key: String) -> [APIQuestion]? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }

    func set(_ key: String, _ value: [APIQuestion]) {
        lock.lock(); defer { lock.unlock() }
        store[key] = value
    }

    func remove(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
}

actor QuestionPackCache {
    static let shared = QuestionPackCache()

    private static let memoryCache = MemoryCache()

    private let cacheDir: URL
    private let versionsKey = "questionPackVersions"

    /// The two-letter language code for question fetching.
    /// Respects the user's in-app language selection; falls back to system locale.
    nonisolated static var appLanguage: String {
        let stored = UserDefaults.standard.string(forKey: "selectedLanguageCode") ?? "system"
        if stored == "en" { return "en" }
        if stored == "no" { return "no" }
        let raw = Bundle.main.preferredLocalizations.first ?? "en"
        let code = Locale(identifier: raw).language.languageCode?.identifier ?? "en"
        switch code {
        case "no", "nb", "nn": return "no"
        case "en":             return "en"
        default:               return "en"
        }
    }

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDir = docs.appendingPathComponent("QuestionPacks", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: – Public

    /// Checks for updates for the given modes (in the current app language) and
    /// downloads any new packs. Safe to call on every launch.
    func syncIfNeeded(modes: [String]) async {
        guard !modes.isEmpty else { return }
        let lang = QuestionPackCache.appLanguage
        do {
            let query = modes.joined(separator: ",")
            let remote: QuestionVersionsResponse = try await APIClient.shared.get(
                "questions/versions",
                query: ["modes": query, "lang": lang]
            )
            let local = loadLocalVersions()
            for mode in modes {
                guard let info = remote.versions[mode] else { continue }
                let cacheKey = "\(mode)_\(info.language)"
                if local[cacheKey] == nil || local[cacheKey]! < info.version {
                    try await download(mode: mode, language: info.language, version: info.version)
                }
            }
        } catch {
            // Non-fatal: existing cache (or bundle fallback) will be used
        }
    }

    /// Returns cached questions for a mode in the current app language, or nil
    /// if not yet downloaded. Falls back to English if no pack exists for the
    /// app language (e.g. a mode that only has English questions).
    nonisolated func questions(for mode: String) -> [APIQuestion]? {
        let lang = QuestionPackCache.appLanguage
        if let qs = questions(for: mode, language: lang) { return qs }
        return lang == "en" ? nil : questions(for: mode, language: "en")
    }

    /// Returns cached questions for a specific mode and language, or nil if not
    /// yet downloaded. Results are cached in memory to avoid repeated disk reads.
    nonisolated func questions(for mode: String, language: String) -> [APIQuestion]? {
        let key = "\(mode)_\(language)"
        if let cached = Self.memoryCache.get(key) { return cached }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = docs.appendingPathComponent("QuestionPacks/\(key).json")
        guard let data = try? Data(contentsOf: file),
              let questions = try? JSONDecoder().decode([APIQuestion].self, from: data)
        else { return nil }
        Self.memoryCache.set(key, questions)
        return questions
    }

    // MARK: – Private

    private func download(mode: String, language: String, version: Int) async throws {
        let pack: QuestionPackResponse = try await APIClient.shared.get(
            "questions/\(mode)",
            query: ["lang": language]
        )
        let data = try JSONEncoder().encode(pack.questions)
        let cacheKey = "\(mode)_\(pack.language)"
        let tmpFile = cacheDir.appendingPathComponent("\(cacheKey).tmp.json")
        let finalFile = packFile(mode: mode, language: pack.language)
        try data.write(to: tmpFile, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(finalFile, withItemAt: tmpFile)
        try? FileManager.default.removeItem(at: tmpFile)
        Self.memoryCache.remove(cacheKey)
        var versions = loadLocalVersions()
        versions[cacheKey] = version
        saveLocalVersions(versions)
    }

    private func packFile(mode: String, language: String) -> URL {
        cacheDir.appendingPathComponent("\(mode)_\(language).json")
    }

    private func loadLocalVersions() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: versionsKey),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveLocalVersions(_ versions: [String: Int]) {
        guard let data = try? JSONEncoder().encode(versions) else { return }
        UserDefaults.standard.set(data, forKey: versionsKey)
    }
}

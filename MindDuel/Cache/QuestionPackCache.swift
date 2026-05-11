import Foundation

/// Manages versioned question pack downloads. Packs are stored on disk so they
/// survive app restarts and work offline. The cache performs atomic swaps: the
/// new pack is fully written before the old one is replaced.
actor QuestionPackCache {
    static let shared = QuestionPackCache()

    private let cacheDir: URL
    private let versionsKey = "questionPackVersions"

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDir = docs.appendingPathComponent("QuestionPacks", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: – Public

    /// Checks for updates for the given modes and downloads any new packs.
    /// Safe to call on every launch.
    func syncIfNeeded(modes: [String]) async {
        guard !modes.isEmpty else { return }
        do {
            let query = modes.joined(separator: ",")
            let remote: QuestionVersionsResponse = try await APIClient.shared.get(
                "questions/versions",
                query: ["modes": query]
            )
            let local = loadLocalVersions()
            for mode in modes {
                guard let remoteVer = remote.versions[mode] else { continue }
                if local[mode] == nil || local[mode]! < remoteVer {
                    try await download(mode: mode, version: remoteVer)
                }
            }
        } catch {
            // Non-fatal: existing cache (or bundle fallback) will be used
        }
    }

    /// Returns cached questions for a mode, or nil if not yet downloaded.
    func questions(for mode: String) -> [APIQuestion]? {
        let file = packFile(mode: mode)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode([APIQuestion].self, from: data)
    }

    // MARK: – Private

    private func download(mode: String, version: Int) async throws {
        let pack: QuestionPackResponse = try await APIClient.shared.get("questions/\(mode)")
        let data = try JSONEncoder().encode(pack.questions)
        let tmpFile = cacheDir.appendingPathComponent("\(mode).tmp.json")
        let finalFile = packFile(mode: mode)
        try data.write(to: tmpFile, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(finalFile, withItemAt: tmpFile)
        try? FileManager.default.removeItem(at: tmpFile)
        var versions = loadLocalVersions()
        versions[mode] = version
        saveLocalVersions(versions)
    }

    private func packFile(mode: String) -> URL {
        cacheDir.appendingPathComponent("\(mode).json")
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

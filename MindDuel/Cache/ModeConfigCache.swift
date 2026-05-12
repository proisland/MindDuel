import Foundation

/// Fetches active game modes from the backend and caches them for offline use.
@MainActor
final class ModeConfigCache: ObservableObject {
    static let shared = ModeConfigCache()

    @Published private(set) var activeSlugs: Set<String> = []

    private let cacheKey = "cachedActiveSlugs"
    private init() { loadFromDisk() }

    func refresh() async {
        do {
            struct SlimMode: Decodable { let slug: String }
            struct Envelope: Decodable { let modes: [SlimMode] }
            let envelope: Envelope = try await APIClient.shared.get("modes")
            activeSlugs = Set(envelope.modes.map(\.slug))
            saveToDisk(Array(activeSlugs))
        } catch {
            // Keep existing cached slugs on network failure
        }
    }

    func isActive(slug: String) -> Bool {
        guard !activeSlugs.isEmpty else { return true }
        return activeSlugs.contains(slug)
    }

    private func saveToDisk(_ slugs: [String]) {
        UserDefaults.standard.set(slugs, forKey: cacheKey)
    }

    private func loadFromDisk() {
        guard let stored = UserDefaults.standard.array(forKey: cacheKey) as? [String] else { return }
        activeSlugs = Set(stored)
    }
}

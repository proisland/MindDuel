import Foundation

/// Fetches active game modes from the backend and caches them for offline use.
@MainActor
final class ModeConfigCache: ObservableObject {
    static let shared = ModeConfigCache()

    @Published private(set) var serverModes: [ServerMode] = []

    /// Set of active slugs — used by ModePreferences.activeOrder filtering.
    var activeSlugs: Set<String> { Set(serverModes.map(\.slug)) }

    /// Server-only modes: active modes that have no matching `GameMode` enum case.
    var serverOnlyModes: [ServerMode] {
        serverModes.filter { $0.gameMode == nil }
    }

    private let cacheKey = "cachedServerModes_v2"
    private init() { loadFromDisk() }

    func refresh() async {
        do {
            struct Envelope: Decodable { let modes: [ServerMode] }
            let envelope: Envelope = try await APIClient.shared.get("modes")
            serverModes = envelope.modes
            saveToDisk(envelope.modes)
        } catch {
            // Keep existing cached modes on network failure
        }
    }

    func isActive(slug: String) -> Bool {
        guard !serverModes.isEmpty else { return true }
        return serverModes.contains { $0.slug == slug }
    }

    func serverMode(for slug: String) -> ServerMode? {
        serverModes.first { $0.slug == slug }
    }

    private func saveToDisk(_ modes: [ServerMode]) {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let modes = try? JSONDecoder().decode([ServerMode].self, from: data) else { return }
        serverModes = modes
    }
}

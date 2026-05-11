import Foundation

/// Fetches active game modes from the backend and caches them for offline use.
@MainActor
final class ModeConfigCache: ObservableObject {
    static let shared = ModeConfigCache()

    @Published private(set) var modes: [ModeResponse] = []

    private let cacheKey = "cachedModes"
    private init() { loadFromDisk() }

    func refresh() async {
        do {
            let fetched: [ModeResponse] = try await APIClient.shared.get("modes")
            modes = fetched
            saveToDisk(fetched)
        } catch {
            // Keep existing cached modes on network failure
        }
    }

    func isActive(slug: String) -> Bool {
        guard let mode = modes.first(where: { $0.slug == slug }) else { return true }
        return mode.isActive
    }

    private func saveToDisk(_ modes: [ModeResponse]) {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder.api.decode([ModeResponse].self, from: data)
        else { return }
        modes = decoded
    }
}

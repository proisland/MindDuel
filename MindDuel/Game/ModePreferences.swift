import Foundation
import SwiftUI

/// Per-user preferences for the home screen mode list: which modes are
/// favorites, and the user's custom ordering used by both the favorites grid
/// and the quick-access row.
@MainActor final class ModePreferences: ObservableObject {
    static let shared = ModePreferences()

    @Published private(set) var favorites: Set<GameMode>
    @Published private(set) var order: [GameMode]

    /// Maximum number of favorites the user can pick (matches the
    /// 2×2 favorites grid on the home screen — issue #124).
    static let maxFavorites = 4

    private static let favKey   = "modePrefs.favorites"
    private static let orderKey = "modePrefs.order"

    private init() {
        let d = UserDefaults.standard
        if let raw = d.array(forKey: Self.favKey) as? [String] {
            favorites = Set(raw.compactMap(GameMode.init(rawValue:)))
        } else {
            // Default favorites: first four modes in canonical order.
            favorites = Set(GameMode.allCases.prefix(Self.maxFavorites))
        }
        if let raw = d.array(forKey: Self.orderKey) as? [String] {
            let decoded = raw.compactMap(GameMode.init(rawValue:))
            // Ensure any newly-added modes still appear, appended at the end.
            let missing = GameMode.allCases.filter { !decoded.contains($0) }
            order = decoded + missing
        } else {
            order = GameMode.allCases
        }
        // Migrate legacy state that may have stored more than the cap.
        if favorites.count > Self.maxFavorites {
            let trimmed = order.filter { favorites.contains($0) }.prefix(Self.maxFavorites)
            favorites = Set(trimmed)
            persistFavorites()
        }
    }

    func isFavorite(_ mode: GameMode) -> Bool { favorites.contains(mode) }

    /// True when the user is at the cap and must remove a favorite before
    /// adding another. Used by AllModesSheet to grey out the star button.
    var isAtFavoriteCap: Bool { favorites.count >= Self.maxFavorites }

    /// Returns false if the toggle was rejected because the cap was hit.
    @discardableResult
    func toggleFavorite(_ mode: GameMode) -> Bool {
        if favorites.contains(mode) {
            favorites.remove(mode)
        } else {
            guard favorites.count < Self.maxFavorites else { return false }
            favorites.insert(mode)
        }
        persistFavorites()
        return true
    }

    func move(from source: Int, to destination: Int) {
        guard order.indices.contains(source) else { return }
        var next = order
        let item = next.remove(at: source)
        let clamped = max(0, min(next.count, destination))
        next.insert(item, at: clamped)
        order = next
        persistOrder()
    }

    /// Modes used to fill the featured grid: favorites first (in custom
    /// order), then top-played non-favorites until we hit `count`.
    func featured(count: Int = 4) -> [GameMode] {
        let favs = order.filter(favorites.contains)
        let fillers = order.filter { !favorites.contains($0) }
        return Array((favs + fillers).prefix(count))
    }

    private func persistFavorites() {
        UserDefaults.standard.set(favorites.map(\.rawValue), forKey: Self.favKey)
    }

    private func persistOrder() {
        UserDefaults.standard.set(order.map(\.rawValue), forKey: Self.orderKey)
    }
}

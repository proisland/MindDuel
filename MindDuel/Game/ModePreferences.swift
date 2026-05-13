import Foundation
import SwiftUI

/// Wraps either a known (GameMode enum) or server-only mode for unified ordering.
enum AnyMode: Identifiable {
    case known(GameMode)
    case server(ServerMode)

    var id: String { slug }

    var slug: String {
        switch self {
        case .known(let m):  return m.slug
        case .server(let m): return m.slug
        }
    }
}

/// Per-user preferences for the home screen mode list: which modes are
/// favorites, and the user's custom ordering used by both the favorites grid
/// and the quick-access row.
@MainActor final class ModePreferences: ObservableObject {
    static let shared = ModePreferences()

    @Published private(set) var favorites: Set<GameMode>
    @Published private(set) var combinedOrder: [String]

    /// Maximum number of favorites the user can pick (matches the
    /// 2×2 favorites grid on the home screen — issue #124).
    static let maxFavorites = 4

    private static let favKey          = "modePrefs.favorites"
    private static let combinedOrderKey = "modePrefs.combinedOrder"
    // Legacy keys — read once during migration, then ignored.
    private static let orderKey        = "modePrefs.order"
    private static let serverOrderKey  = "modePrefs.serverOrder"

    private init() {
        let d = UserDefaults.standard
        if let raw = d.array(forKey: Self.favKey) as? [String] {
            favorites = Set(raw.compactMap(GameMode.init(rawValue:)))
        } else {
            favorites = Set(GameMode.allCases.prefix(Self.maxFavorites))
        }
        if let raw = d.array(forKey: Self.combinedOrderKey) as? [String], !raw.isEmpty {
            combinedOrder = raw
        } else {
            // Migrate: merge old rawValue-based order + serverOrder into slug-based combinedOrder.
            var merged: [String] = []
            if let knownRaw = d.array(forKey: Self.orderKey) as? [String] {
                merged += knownRaw.compactMap(GameMode.init(rawValue:)).map(\.slug)
            } else {
                merged += GameMode.allCases.map(\.slug)
            }
            merged += (d.array(forKey: Self.serverOrderKey) as? [String]) ?? []
            combinedOrder = merged
        }
        // Migrate legacy state that may have stored more than the cap.
        if favorites.count > Self.maxFavorites {
            let trimmed = combinedOrder
                .compactMap(GameMode.init(slug:))
                .filter { favorites.contains($0) }
                .prefix(Self.maxFavorites)
            favorites = Set(trimmed)
            persistFavorites()
        }
    }

    /// All active modes in the user's custom unified order (known + server-only).
    var activeCombinedOrder: [AnyMode] {
        let cache = ModeConfigCache.shared
        var result: [AnyMode] = []
        var seen = Set<String>()
        for slug in combinedOrder {
            guard !seen.contains(slug), cache.isActive(slug: slug) else {
                seen.insert(slug)
                continue
            }
            seen.insert(slug)
            if let gm = GameMode(slug: slug) {
                result.append(.known(gm))
            } else if let sm = cache.serverModes.first(where: { $0.slug == slug }) {
                result.append(.server(sm))
            }
        }
        // Append any active modes not yet in combinedOrder.
        for m in cache.serverModes where !seen.contains(m.slug) {
            if let gm = GameMode(slug: m.slug) {
                result.append(.known(gm))
            } else {
                result.append(.server(m))
            }
            seen.insert(m.slug)
        }
        return result
    }

    /// Known (GameMode enum) modes in unified order — used by the favorites
    /// grid, quick-access row, and featured() helper.
    var activeOrder: [GameMode] {
        activeCombinedOrder.compactMap {
            if case .known(let m) = $0 { return m }
            return nil
        }
    }

    /// Server-only modes in unified order — kept for backward compatibility.
    var activeServerOrder: [ServerMode] {
        activeCombinedOrder.compactMap {
            if case .server(let m) = $0 { return m }
            return nil
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

    func moveCombined(fromOffsets source: IndexSet, toOffset destination: Int) {
        var slugs = activeCombinedOrder.map(\.slug)
        slugs.move(fromOffsets: source, toOffset: destination)
        combinedOrder = slugs
        persistCombinedOrder()
    }

    /// Modes used to fill the featured grid: favorites first (in custom
    /// order), then top-played non-favorites until we hit `count`.
    /// Only includes modes the backend reports as active.
    func featured(count: Int = 4) -> [GameMode] {
        let active = activeOrder
        let favs = active.filter(favorites.contains)
        let fillers = active.filter { !favorites.contains($0) }
        return Array((favs + fillers).prefix(count))
    }

    private func persistFavorites() {
        UserDefaults.standard.set(favorites.map(\.rawValue), forKey: Self.favKey)
    }

    private func persistCombinedOrder() {
        UserDefaults.standard.set(combinedOrder, forKey: Self.combinedOrderKey)
    }
}

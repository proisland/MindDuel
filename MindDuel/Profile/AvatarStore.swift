import SwiftUI

/// #71: lets the user customise their own avatar with either an emoji or a
/// photo from the library. Friends/opponents still render initial-based
/// avatars; only the local user is customisable.
@MainActor final class AvatarStore: ObservableObject {
    static let shared = AvatarStore()

    @Published var emoji: String? {
        didSet { UserDefaults.standard.set(emoji, forKey: Self.emojiKey) }
    }
    @Published var imageData: Data? {
        didSet {
            if let data = imageData { try? data.write(to: Self.imageURL) }
            else { try? FileManager.default.removeItem(at: Self.imageURL) }
        }
    }
    /// #118: signed-in user's username, set by `RootView` when auth flips
    /// to `.authenticated`. `MDAvatar` reads this so any avatar rendered
    /// for "me" picks up the customisation regardless of whose call site
    /// it is — home top-bar, in-game player chip, scoreboard own row, etc.
    @Published var ownUsername: String?

    static let emojiKey = "ownAvatarEmoji"
    static var imageURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("ownAvatar.jpg")
    }

    private init() {
        emoji = UserDefaults.standard.string(forKey: Self.emojiKey)
        if let data = try? Data(contentsOf: Self.imageURL) { imageData = data }
    }

    /// True when the supplied username belongs to the signed-in user.
    /// Case-insensitive so casing differences across views don't matter.
    func isOwnUsername(_ username: String) -> Bool {
        guard let own = ownUsername else { return false }
        return own.compare(username, options: .caseInsensitive) == .orderedSame
    }
}

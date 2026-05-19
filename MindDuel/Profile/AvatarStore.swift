import SwiftUI

struct PresetAvatarItem: Decodable, Identifiable {
    let id: String
    let url: String
    let label: String
    let sortOrder: Int
}

struct PresetAvatarsResponse: Decodable {
    let presets: [PresetAvatarItem]
}

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
    /// Remote URL of the uploaded avatar photo (visible to other users).
    @Published var avatarUrl: String? {
        didSet { UserDefaults.standard.set(avatarUrl, forKey: Self.avatarUrlKey) }
    }
    /// Cached preset avatar list fetched from backend.
    @Published private(set) var presets: [PresetAvatarItem] = []
    /// #118: signed-in user's username, set by `RootView` when auth flips
    /// to `.authenticated`. `MDAvatar` reads this so any avatar rendered
    /// for "me" picks up the customisation regardless of whose call site
    /// it is — home top-bar, in-game player chip, scoreboard own row, etc.
    @Published var ownUsername: String?

    static let emojiKey    = "ownAvatarEmoji"
    static let avatarUrlKey = "ownAvatarUrl"
    static var imageURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("ownAvatar.jpg")
    }

    private init() {
        emoji     = UserDefaults.standard.string(forKey: Self.emojiKey)
        avatarUrl = UserDefaults.standard.string(forKey: Self.avatarUrlKey)
        if let data = try? Data(contentsOf: Self.imageURL) { imageData = data }
    }

    /// True when the supplied username belongs to the signed-in user.
    /// Case-insensitive so casing differences across views don't matter.
    func isOwnUsername(_ username: String) -> Bool {
        guard let own = ownUsername else { return false }
        return own.compare(username, options: .caseInsensitive) == .orderedSame
    }

    /// Fetch the active preset avatar list from the backend.
    func fetchPresets() async {
        let resp: PresetAvatarsResponse? = try? await APIClient.shared.get("avatars/presets")
        presets = resp?.presets ?? []
    }

    /// Select a preset avatar: update avatarUrl, clear local custom photo/emoji.
    func selectPreset(_ preset: PresetAvatarItem) {
        imageData = nil
        emoji = nil
        avatarUrl = preset.url
        Task {
            struct Body: Encodable { let avatarUrl: String? }
            let _: Empty? = try? await APIClient.shared.patch("me", body: Body(avatarUrl: preset.url))
        }
    }

    /// Upload imageData to R2 via the backend proxy, then persist the public URL to UserDefaults.
    func uploadAvatar(imageData: Data) async {
        do {
            struct Body: Encodable { let data: String }
            struct Response: Decodable { let publicUrl: String }
            let resp: Response = try await APIClient.shared.post(
                "me/avatar/image",
                body: Body(data: imageData.base64EncodedString())
            )
            avatarUrl = resp.publicUrl
        } catch {
            // Upload failure is non-fatal; the local photo is still shown for the user themselves.
        }
    }
}

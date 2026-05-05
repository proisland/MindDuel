import SwiftUI
import UIKit

enum AvatarSize {
    case sm, md, lg

    var dimension: CGFloat {
        switch self {
        case .sm: return 26
        case .md: return 32
        case .lg: return 56
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .sm: return 9
        case .md: return 11
        case .lg: return 22
        }
    }
}

struct MDAvatar: View {
    let username: String
    var size: AvatarSize = .md
    /// #71: when set, overrides the initial-based fallback with a custom
    /// avatar (emoji or user-picked photo). Only the local user passes this.
    var customEmoji: String? = nil
    var customImageData: Data? = nil
    /// #118: when call sites don't explicitly pass a custom avatar but the
    /// username matches the signed-in user, fall back to the values stored
    /// in `AvatarStore.shared` so a customised avatar shows up everywhere
    /// (home top-bar, in-game player chips, scoreboard own row, …).
    @ObservedObject private var avatarStore = AvatarStore.shared

    var body: some View {
        let isOwn = avatarStore.isOwnUsername(username)
        let resolvedData: Data? = customImageData ?? (isOwn ? avatarStore.imageData : nil)
        let resolvedEmoji: String? = customEmoji ?? (isOwn ? avatarStore.emoji : nil)
        return ZStack {
            if let data = resolvedData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.dimension, height: size.dimension)
                    .clipShape(Circle())
            } else if let emoji = resolvedEmoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size.dimension * 0.6))
                    .frame(width: size.dimension, height: size.dimension)
                    .background(Color.mdAccentDeep)
                    .clipShape(Circle())
            } else {
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: size.fontSize, weight: .bold))
                    .foregroundStyle(Color.mdText)
                    .frame(width: size.dimension, height: size.dimension)
                    .background(Color.mdAccentDeep)
                    .clipShape(Circle())
            }
        }
        .overlay(Circle().stroke(Color.mdAccent, lineWidth: 1))
    }
}

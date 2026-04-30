import SwiftUI

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

    var body: some View {
        Text(String(username.prefix(1)).uppercased())
            .font(.system(size: size.fontSize, weight: .bold))
            .foregroundStyle(Color.mdText)
            .frame(width: size.dimension, height: size.dimension)
            .background(Color.mdAccentDeep)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.mdAccent, lineWidth: 1))
    }
}

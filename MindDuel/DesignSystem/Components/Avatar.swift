import SwiftUI

enum AvatarSize {
    case sm, md, lg

    var dimension: CGFloat {
        switch self {
        case .sm: return 32
        case .md: return 44
        case .lg: return 64
        }
    }

    var textStyle: MDTextStyle {
        switch self {
        case .sm: return .caption
        case .md: return .body
        case .lg: return .heading
        }
    }
}

struct MDAvatar: View {
    let username: String
    var size: AvatarSize = .md

    var body: some View {
        Text(String(username.prefix(1)).uppercased())
            .mdStyle(size.textStyle)
            .frame(width: size.dimension, height: size.dimension)
            .background(Color.mdAccentDeep)
            .clipShape(Circle())
    }
}

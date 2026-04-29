import SwiftUI

enum PillVariant {
    case accent, pink, green, amber, red, neutral
}

struct MDPillTag: View {
    let label: String
    var variant: PillVariant = .neutral

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(labelColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch variant {
        case .accent:  return .mdAccentSoft
        case .pink:    return .mdPinkSoft
        case .green:   return .mdGreenSoft
        case .amber:   return .mdAmberSoft
        case .red:     return .mdRedSoft
        case .neutral: return .mdSurface2
        }
    }

    private var labelColor: Color {
        switch variant {
        case .accent:  return .mdAccent
        case .pink:    return .mdPink
        case .green:   return .mdGreen
        case .amber:   return .mdAmber
        case .red:     return .mdRed
        case .neutral: return .mdText2
        }
    }
}

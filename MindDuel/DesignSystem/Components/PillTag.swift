import SwiftUI

enum PillVariant {
    case accent, pink, green, amber, red, neutral
}

struct MDPillTag: View {
    let label: String
    var variant: PillVariant = .neutral

    var body: some View {
        Text(label)
            .mdStyle(.footnote)
            .foregroundStyle(labelColor)
            .padding(.horizontal, MDSpacing.sm)
            .padding(.vertical, MDSpacing.xxs)
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

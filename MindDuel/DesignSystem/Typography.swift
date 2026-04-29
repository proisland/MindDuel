import SwiftUI

enum MDTextStyle {
    case display   // 30 pt Heavy  – score, store tall
    case title     // 20 pt Heavy  – hjemskjerm-velkomst
    case heading   // 17 pt Heavy  – skjermoverskrifter, modale titler
    case title2    // 15 pt Heavy  – profilnavn, kortoverskrifter
    case subtitle  // 14 pt Bold   – topbar-titler
    case body      // 13 pt Bold   – modusnavn, viktige stats
    case bodyMd    // 12 pt Bold   – knapper, scoreboard-rader
    case caption   // 11 pt SemiBold – sekundærlabels
    case footnote  // 10 pt Medium – tidsstempler
    case micro     //  9 pt Medium – statusbar
}

extension View {
    func mdStyle(_ style: MDTextStyle) -> some View {
        modifier(MDTypographyModifier(style: style))
    }
}

private struct MDTypographyModifier: ViewModifier {
    let style: MDTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .foregroundStyle(style.defaultColor)
    }
}

private extension MDTextStyle {
    var font: Font {
        switch self {
        case .display:  return .system(size: 30, weight: .heavy)
        case .title:    return .system(size: 20, weight: .heavy)
        case .heading:  return .system(size: 17, weight: .heavy)
        case .title2:   return .system(size: 15, weight: .heavy)
        case .subtitle: return .system(size: 14, weight: .bold)
        case .body:     return .system(size: 13, weight: .bold)
        case .bodyMd:   return .system(size: 12, weight: .bold)
        case .caption:  return .system(size: 11, weight: .semibold)
        case .footnote: return .system(size: 10, weight: .medium)
        case .micro:    return .system(size:  9, weight: .medium)
        }
    }

    var defaultColor: Color {
        switch self {
        case .caption, .footnote, .micro: return .mdText2
        default:                          return .mdText
        }
    }
}

import SwiftUI

enum MDTextStyle {
    case display   // 30 pt Heavy  – score, store tall
    case title     // 20 pt Heavy  – hjemskjerm-velkomst
    case heading   // 17 pt Heavy  – skjermoverskrifter, modale titler
    case title2    // 15 pt Heavy  – profilnavn, kortoverskrifter
    case subtitle  // 14 pt Bold   – topbar-titler
    case body      // 14 pt Bold   – modusnavn, viktige stats
    case bodyMd    // 13 pt Bold   – knapper, scoreboard-rader
    case caption   // 12 pt SemiBold – sekundærlabels
    case footnote  // 11 pt Medium – tidsstempler
    case micro     // 10 pt Medium – statusbar
}

extension View {
    func mdStyle(_ style: MDTextStyle) -> some View {
        modifier(MDTypographyModifier(style: style))
    }
}

private struct MDTypographyModifier: ViewModifier {
    let style: MDTextStyle

    @ScaledMetric(relativeTo: .body) private var displaySize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var headingSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var title2Size: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var subtitleSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var bodyMdSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var captionSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var footnoteSize: CGFloat = 11
    @ScaledMetric(relativeTo: .body) private var microSize: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .font(resolvedFont)
            .foregroundStyle(style.defaultColor)
            .tracking(style == .micro ? 0.9 : 0)
    }

    private var resolvedFont: Font {
        switch style {
        case .display:  return .system(size: displaySize,  weight: .heavy)
        case .title:    return .system(size: titleSize,    weight: .heavy)
        case .heading:  return .system(size: headingSize,  weight: .heavy)
        case .title2:   return .system(size: title2Size,   weight: .heavy)
        case .subtitle: return .system(size: subtitleSize, weight: .bold)
        case .body:     return .system(size: bodySize,     weight: .bold)
        case .bodyMd:   return .system(size: bodyMdSize,   weight: .bold)
        case .caption:  return .system(size: captionSize,  weight: .semibold)
        case .footnote: return .system(size: footnoteSize, weight: .semibold)
        case .micro:    return .system(size: microSize,    weight: .bold)
        }
    }
}

private extension MDTextStyle {
    var defaultColor: Color {
        switch self {
        case .caption, .footnote, .micro: return .mdText2
        default:                          return .mdText
        }
    }
}

import SwiftUI

struct MDModeCard: View {
    let mode: GameMode
    var score: Int = 0
    var level: Int = 1
    var maxLevel: Int
    var compact: Bool = false
    let action: () -> Void

    private var iconSymbol: String {
        switch mode {
        case .pi: return "π"
        case .math: return "∑"
        case .chemistry: return "⚗︎"
        }
    }

    private var iconBg: Color {
        switch mode {
        case .pi: return .mdAccentDeep
        case .math: return .mdPinkDeep
        case .chemistry: return .mdGreen
        }
    }

    private var accentColor: Color {
        switch mode {
        case .pi: return .mdAccent
        case .math: return .mdPink
        case .chemistry: return .mdGreen
        }
    }

    private var localizedTitle: String {
        switch mode {
        case .pi: return String(localized: "mode_pi")
        case .math: return String(localized: "mode_math")
        case .chemistry: return String(localized: "mode_chemistry")
        }
    }

    private var progress: Double {
        guard maxLevel > 0 else { return 0 }
        return Double(level - 1) / Double(maxLevel)
    }

    var body: some View {
        Button(action: action) {
            let iconSize: CGFloat = compact ? 38 : 44
            let iconFont: CGFloat = compact ? 18 : 22
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(iconBg)
                        .frame(width: iconSize, height: iconSize)
                    Text(iconSymbol)
                        .font(.system(size: iconFont, weight: .heavy))
                        .foregroundStyle(Color.mdText)
                }

                Text(verbatim: localizedTitle)
                    .mdStyle(.bodyMd)

                Text("\(score)p")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(accentColor)

                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.mdSurface2)
                                .frame(height: 4)
                            Capsule()
                                .fill(accentColor)
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(level)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                }

                Text(String(format: String(localized: "level_of_format"), level, maxLevel))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdText3)
            }
            .padding(.vertical, compact ? 11 : 14)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mdBorder2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

/// Compact horizontal mode card used on the home and profile screens.
/// Big icon left, name + score + level bar right, mode-tinted surface.
struct MDFeaturedCard: View {
    let mode: GameMode
    let score: Int
    let level: Int
    var maxLevel: Int = 20
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(mode.accentColor.opacity(0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(mode.accentColor.opacity(0.27), lineWidth: 1.5)
                    )
                ModeGlyph(mode: mode, size: 22, color: mode.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.localizedTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mdText)
                Text(formatPoints(score))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(mode.accentColor)
                LevelBar(level: level, maxLevel: maxLevel, color: mode.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mode.deepBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(mode.accentColor.opacity(0.18), lineWidth: 1)
        )

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Thin per-mode level bar used by the featured card.
struct LevelBar: View {
    let level: Int
    let maxLevel: Int
    let color: Color

    private var progress: Double {
        guard maxLevel > 0 else { return 0 }
        return min(1, Double(level) / Double(maxLevel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: String(localized: "level_of_format"), level, maxLevel))
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(Color.mdText3)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 2)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 2)
                }
            }
            .frame(height: 2)
        }
    }
}

/// Compact pill used in the home screen's horizontal "Quick access" row.
struct MDQuickPill: View {
    let mode: GameMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(mode.accentColor.opacity(0.12))
                    ModeGlyph(mode: mode, size: 16, color: mode.accentColor)
                }
                .frame(width: 34, height: 34)

                Text(mode.localizedTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mdText3)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 66)
            .background(mode.deepBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(mode.accentColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

func formatPoints(_ n: Int) -> String {
    if n >= 10_000 { return "\(n / 1000)k \(String(localized: "points_word"))" }
    return "\(n) \(String(localized: "points_word"))"
}

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
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(color)
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

                Text(quickPillTitle(mode))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mdText3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 78)
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

/// Quick-access pill for a server-only mode (no GameMode enum case).
struct ServerModeQuickPill: View {
    let serverMode: ServerMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(serverMode.accentColor.opacity(0.12))
                    ServerModeGlyph(iconSymbol: serverMode.iconSymbol, size: 16,
                                    color: serverMode.accentColor)
                }
                .frame(width: 34, height: 34)

                Text(serverMode.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mdText3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 78)
            .background(serverMode.accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(serverMode.accentColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Compact horizontal featured card for a server-only mode — mirrors MDFeaturedCard layout.
struct MDServerFeaturedCard: View {
    let serverMode: ServerMode
    let score: Int
    let level: Int
    var maxLevel: Int = 20
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(serverMode.accentColor.opacity(0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(serverMode.accentColor.opacity(0.27), lineWidth: 1.5)
                    )
                ServerModeGlyph(iconSymbol: serverMode.iconSymbol, size: 22,
                                color: serverMode.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(serverMode.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mdText)
                Text(formatPoints(score))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(serverMode.accentColor)
                LevelBar(level: level, maxLevel: maxLevel, color: serverMode.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(serverMode.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(serverMode.accentColor.opacity(0.18), lineWidth: 1)
        )

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Breaks "Naturvitenskap" between "Natur" and "vitenskap" on the two-line
/// pill labels so the science card matches the height of the others without
/// shrinking text. English ("Science") stays on one line.
func quickPillTitle(_ mode: GameMode) -> String {
    let title = mode.localizedTitle
    if mode == .science, title == "Naturvitenskap" {
        return "Natur\nvitenskap"
    }
    return title
}

func formatPoints(_ n: Int) -> String {
    if n >= 10_000 { return "\(n / 1000)k \(String(localized: "points_word"))" }
    return "\(n) \(String(localized: "points_word"))"
}

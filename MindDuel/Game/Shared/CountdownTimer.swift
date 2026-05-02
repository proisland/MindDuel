import SwiftUI

/// Prominent countdown 10 → 0 shown above the question card (#41).
/// Replaces the tiny count-up label that used to live under the skip
/// button — players asked for a clearer signal that they have ten seconds.
struct CountdownTimer: View {
    let elapsedSeconds: Double

    private var remaining: Double {
        max(0, 10.0 - elapsedSeconds)
    }

    private var color: Color {
        switch remaining {
        case ..<3:  return .mdRed
        case ..<6:  return .mdAmber
        default:    return .mdText2
        }
    }

    var body: some View {
        HStack(spacing: MDSpacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .semibold))
            Text(String(format: "%.1fs", remaining))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .animation(.easeInOut(duration: 0.15), value: color)
    }
}

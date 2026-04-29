import SwiftUI

struct SkipButton: View {
    let elapsedSeconds: Double
    let onSkip: () -> Void

    private var timerLabel: String {
        let suffix = String(localized: "timer_seconds_suffix")
        return String(format: "%.1f \(suffix)", elapsedSeconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onSkip) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.mdText2)
                    .frame(width: 44, height: 44)
                    .background(Color.mdSurface2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.mdAccent, lineWidth: 1.5))
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                Text(timerLabel)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.mdText3)
        }
    }
}

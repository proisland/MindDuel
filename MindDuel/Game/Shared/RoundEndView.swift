import SwiftUI

struct RoundEndView: View {
    let correctCount: Int
    let avgTimeSeconds: Double
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    private var scorePoints: Int { correctCount * 45 }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: MDSpacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.mdAmber)

                    Text(String(localized: "round_over_title"))
                        .mdStyle(.heading)
                        .tracking(0.5)
                        .foregroundStyle(Color.mdText2)

                    Text("\(scorePoints)p")
                        .mdStyle(.display)
                }

                HStack(spacing: MDSpacing.sm) {
                    StatBox(label: String(localized: "round_correct_label"), value: "\(correctCount)")
                    StatBox(label: String(localized: "round_avg_time_label"),
                            value: String(format: "%.1f s", avgTimeSeconds))
                }
                .padding(.top, MDSpacing.lg)
                .padding(.horizontal, MDSpacing.md)

                Spacer()

                VStack(spacing: MDSpacing.xs) {
                    MDButton(.primary, title: String(localized: "play_again_action"), action: onPlayAgain)
                    MDButton(.ghost, title: String(localized: "back_to_home_action"), action: onHome)
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }
}

private struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: MDSpacing.xxs) {
            Text(value)
                .mdStyle(.title2)
            Text(label)
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MDSpacing.md)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }
}

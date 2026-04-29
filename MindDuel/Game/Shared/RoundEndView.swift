import SwiftUI

struct RoundEndView: View {
    let correctCount: Int
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: MDSpacing.lg) {
                Spacer()

                VStack(spacing: MDSpacing.md) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.mdAmber)

                    Text(String(localized: "round_over_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText2)

                    Text("\(correctCount)")
                        .mdStyle(.display)
                }

                Text(String(format: String(localized: "round_correct_count"), correctCount))
                    .mdStyle(.body)
                    .foregroundStyle(Color.mdText2)
                    .padding(.vertical, MDSpacing.sm)
                    .padding(.horizontal, MDSpacing.md)
                    .background(Color.mdSurface2)
                    .clipShape(Capsule())

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

import SwiftUI

struct QuitGameModal: View {
    let onQuit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: MDSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.mdAmber)

                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "quit_game_title"))
                        .mdStyle(.heading)
                    Text(String(localized: "quit_game_message"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: MDSpacing.xs) {
                    MDButton(.danger, title: String(localized: "quit_confirm_action"), action: onQuit)
                    MDButton(.ghost, title: String(localized: "continue_playing_action"), action: onContinue)
                }
                .padding(.top, MDSpacing.xs)
            }
            .padding(MDSpacing.lg)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mdBorder2, lineWidth: 1))
            .padding(.horizontal, MDSpacing.lg)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

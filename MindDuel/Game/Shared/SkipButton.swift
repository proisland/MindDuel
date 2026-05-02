import SwiftUI

/// Skip-current-question button. The countdown that used to live under
/// this button has moved to `CountdownTimer` at the top of the game
/// view (#41) where it's more prominent.
struct SkipButton: View {
    let elapsedSeconds: Double
    let onSkip: () -> Void

    var body: some View {
        Button(action: onSkip) {
            Image(systemName: "forward.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.mdText2)
                .frame(width: 56, height: 56)
                .background(Color.mdSurface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.mdAccent, lineWidth: 1.5))
        }
    }
}

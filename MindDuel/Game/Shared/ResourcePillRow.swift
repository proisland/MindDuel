import SwiftUI

struct ResourcePillRow: View {
    let lives: Int
    let skips: Int
    @State private var heartScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            ResourcePill(icon: "heart.fill", count: lives, color: .mdRed)
                .scaleEffect(heartScale)
            Spacer()
            ResourcePill(icon: "forward.fill", count: skips, color: .mdAccent)
        }
        .onChange(of: lives) { _ in
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.15)) { heartScale = 0.72 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) { heartScale = 1.0 }
            }
        }
    }
}

private struct ResourcePill: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text("\(count)")
                .mdStyle(.body)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.mdSurface2)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.mdBorder2, lineWidth: 1))
    }
}

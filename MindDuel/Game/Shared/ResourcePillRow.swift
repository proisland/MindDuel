import SwiftUI

struct ResourcePillRow: View {
    let lives: Int
    let skips: Int

    var body: some View {
        HStack {
            ResourcePill(icon: "heart.fill", count: lives, color: .mdRed)
            Spacer()
            ResourcePill(icon: "forward.fill", count: skips, color: .mdAccent)
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

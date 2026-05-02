import SwiftUI

/// Renders the visual glyph for a `GameMode`. Math/Pi/Chemistry use text
/// characters (π/∑/⚗︎); geography uses an SF Symbol because the globe
/// emoji 🌍 fails to render in some contexts (#62).
struct ModeGlyph: View {
    let mode: GameMode
    let size: CGFloat
    var weight: Font.Weight = .heavy
    let color: Color

    var body: some View {
        switch mode {
        case .pi:
            Text("π")
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
        case .math:
            Text("∑")
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
        case .chemistry:
            Text("⚗︎")
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
        case .geography:
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
        }
    }
}

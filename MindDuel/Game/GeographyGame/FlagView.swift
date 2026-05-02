import SwiftUI
import UIKit

/// Renders an emoji string (typically a regional-indicator flag like 🇳🇴)
/// using a UIKit `UILabel`. SwiftUI `Text` was rendering flags as "??" in
/// the simulator regardless of `verbatim:` and `.font(.custom("AppleColorEmoji"))`
/// — UIKit's text stack handles AppleColorEmoji glyphs reliably (#63).
struct FlagView: UIViewRepresentable {
    let emoji: String
    var size: CGFloat = 64

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = .clear
        label.adjustsFontForContentSizeCategory = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.font = UIFont(name: "AppleColorEmoji", size: size)
            ?? UIFont.systemFont(ofSize: size)
        label.text = emoji
    }
}

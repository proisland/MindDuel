import SwiftUI

/// Renders a country flag from a regional-indicator emoji string (e.g. 🇳🇴).
///
/// Background: SwiftUI `Text` and even UIKit `UILabel` were rendering flag
/// emojis as "??" in the simulator regardless of `verbatim:`, custom
/// `AppleColorEmoji` fonts, or other workarounds (#63). The system emoji
/// font shipped with the simulator/device simply doesn't have the flag
/// glyphs in some configurations, and there is no in-process workaround
/// for a missing glyph.
///
/// Solution: parse the regional indicator pair (each scalar in the range
/// U+1F1E6…U+1F1FF maps to A–Z) into a two-letter ISO 3166 country code,
/// then load the actual flag PNG from `flagcdn.com` — an open, free flag
/// image CDN. This bypasses the emoji-font path entirely and renders a
/// real image that can't fail due to missing glyphs.
///
/// Falls back to the emoji `Text` while loading or on failure (e.g.
/// offline). The fallback may still render as "??" but most of the time
/// the network image will load before the user notices.
struct FlagView: View {
    let emoji: String
    var size: CGFloat = 64

    /// Parses two regional-indicator scalars into a lower-cased ISO code,
    /// e.g. "🇳🇴" → "no". Returns nil if the string isn't exactly two
    /// regional indicators.
    private var isoCode: String? {
        let scalars = Array(emoji.unicodeScalars)
        guard scalars.count == 2 else { return nil }
        let regionalBase: UInt32 = 0x1F1E6  // regional indicator A
        var letters = ""
        for s in scalars {
            guard s.value >= regionalBase, s.value <= regionalBase + 25 else { return nil }
            let asciiValue = UInt32(0x41) + (s.value - regionalBase)  // 0x41 = 'A'
            guard let scalar = UnicodeScalar(asciiValue) else { return nil }
            letters.append(Character(scalar))
        }
        return letters.lowercased()
    }

    private var url: URL? {
        guard let code = isoCode else { return nil }
        // w160 ≈ 160px wide PNGs — small enough to load instantly, sharp
        // enough at our 64–80pt render size on retina displays.
        return URL(string: "https://flagcdn.com/w160/\(code).png")
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty, .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(height: size)
    }

    private var fallback: some View {
        // Last-ditch fallback while loading or if the network is down.
        // Looks worse than the real flag but at least conveys something.
        Text(verbatim: emoji)
            .font(.system(size: size))
    }
}

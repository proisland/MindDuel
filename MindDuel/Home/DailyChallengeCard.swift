import SwiftUI

/// Shows today's daily challenge mode. Fetched once per launch; nil while loading.
struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    let onPlay: () -> Void

    private var accentColor: Color {
        Color(hex: challenge.mode.colorHex) ?? .mdAccent
    }

    private var modeName: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "no"
        if lang.hasPrefix("en"), !challenge.mode.nameEn.isEmpty { return challenge.mode.nameEn }
        return challenge.mode.nameNo.isEmpty ? challenge.mode.nameEn : challenge.mode.nameNo
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: MDSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: challenge.mode.iconSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "daily_challenge_title"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.mdText3)
                    Text(modeName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "daily_challenge_subtitle"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.mdText3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mdText3)
            }
            .padding(MDSpacing.md)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class DailyChallengeStore: ObservableObject {
    static let shared = DailyChallengeStore()
    @Published private(set) var challenge: DailyChallenge? = nil

    private init() {}

    func fetch() async {
        guard challenge == nil else { return }
        guard let result = try? await APIClient.shared.get("challenges/daily") as DailyChallenge else { return }
        challenge = result
    }
}

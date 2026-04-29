import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: MDSpacing.xl) {
                Spacer()

                VStack(spacing: MDSpacing.md) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.mdAccentDeep)
                        .frame(width: 62, height: 62)
                        .overlay(
                            Text("M")
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundStyle(Color.mdText)
                        )

                    VStack(spacing: MDSpacing.xs) {
                        Text("MindDuel")
                            .mdStyle(.title)
                        Text(String(localized: "tagline"))
                            .mdStyle(.body)
                            .foregroundStyle(Color.mdText2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, MDSpacing.lg)
                    }
                }

                Spacer()

                VStack(spacing: MDSpacing.md) {
                    MDButton(.primary, title: String(localized: "sign_in_placeholder")) {
                        authState.startGuestSession()
                    }
                    .padding(.horizontal, MDSpacing.lg)

                    Text(String(localized: "sign_in_terms"))
                        .mdStyle(.footnote)
                        .foregroundStyle(Color.mdText3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MDSpacing.xl)
                }
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }
}

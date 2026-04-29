import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: MDSpacing.xl) {
                Spacer()

                VStack(spacing: MDSpacing.md) {
                    Text("MindDuel")
                        .mdStyle(.display)
                    Text("tagline", bundle: nil)
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MDSpacing.lg)
                }

                Spacer()

                MDButton(.primary, title: String(localized: "sign_in_placeholder")) {
                    authState.startGuestSession()
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }
}

import SwiftUI

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState
    @State private var activeMode: GameMode? = nil

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: "MindDuel") {
                    Button { authState.signOut() } label: {
                        MDAvatar(username: username, size: .sm)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        VStack(alignment: .leading, spacing: MDSpacing.xs) {
                            HStack(spacing: MDSpacing.xxs) {
                                Text(String(localized: "welcome_greeting"))
                                    .mdStyle(.title)
                                Text("@\(username)")
                                    .mdStyle(.title)
                            }
                            Text(String(localized: "home_subtitle"))
                                .mdStyle(.body)
                                .foregroundStyle(Color.mdText2)
                        }
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.top, MDSpacing.xl)

                        HStack(spacing: MDSpacing.sm) {
                            MDModeCard(mode: .pi, maxLevel: 20) {
                                activeMode = .pi
                            }
                            MDModeCard(mode: .math, maxLevel: 10) {
                                activeMode = .math
                            }
                        }
                        .padding(.horizontal, MDSpacing.md)
                    }
                    .padding(.bottom, MDSpacing.xl)
                }
            }
        }
        .fullScreenCover(item: $activeMode) { mode in
            switch mode {
            case .pi:
                PiGameView(username: username)
            case .math:
                MathGameView(username: username)
            }
        }
    }
}

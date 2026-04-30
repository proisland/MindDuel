import SwiftUI

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState
    @StateObject private var progression = ProgressionStore.shared
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

                        // Greeting
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

                        // Quota warning banner
                        if progression.isNearQuota {
                            QuotaBanner(
                                used: progression.dailyUsed,
                                total: ProgressionStore.dailyQuota
                            )
                            .padding(.horizontal, MDSpacing.md)
                        }

                        // Mode cards
                        HStack(spacing: MDSpacing.sm) {
                            MDModeCard(
                                mode: .pi,
                                score: progression.piBestScore,
                                level: progression.piPosition / 100 + 1,
                                maxLevel: 20
                            ) { activeMode = .pi }

                            MDModeCard(
                                mode: .math,
                                score: progression.mathBestScore,
                                level: progression.mathLevel,
                                maxLevel: 10
                            ) { activeMode = .math }
                        }
                        .padding(.horizontal, MDSpacing.md)
                    }
                    .padding(.bottom, MDSpacing.xl)
                }
            }
        }
        .onAppear { progression.checkResetQuota() }
        .fullScreenCover(item: $activeMode) { mode in
            switch mode {
            case .pi:   PiGameView(username: username)
            case .math: MathGameView(username: username)
            }
        }
    }
}

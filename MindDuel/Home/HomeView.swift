import SwiftUI

private enum HomeDestination: Identifiable {
    case profile
    case scoreboard
    var id: String {
        switch self {
        case .profile:    return "profile"
        case .scoreboard: return "scoreboard"
        }
    }
}

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState
    @StateObject private var progression = ProgressionStore.shared
    @StateObject private var social = SocialStore.shared
    @State private var activeMode: GameMode? = nil
    @State private var activeDestination: HomeDestination? = nil

    private var pendingBadge: Int { social.totalPendingCount }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: "MindDuel") {
                    Button { activeDestination = .profile } label: {
                        ZStack(alignment: .topTrailing) {
                            MDAvatar(username: username, size: .sm)
                            if pendingBadge > 0 {
                                Text("\(pendingBadge)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(2)
                                    .background(Color.mdRed)
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
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

                        // Scoreboard shortcut
                        scoreboardCard
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
        .fullScreenCover(item: $activeDestination) { dest in
            switch dest {
            case .profile:    ProfileView(username: username, onSignOut: { authState.signOut() })
            case .scoreboard: ScoreboardView(ownUsername: username)
            }
        }
    }

    // MARK: – Scoreboard card

    private var scoreboardCard: some View {
        Button { activeDestination = .scoreboard } label: {
            HStack(spacing: MDSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.mdAccentSoft).frame(width: 40, height: 40)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.mdAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "scoreboard_title"))
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "scoreboard_subtitle"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mdText3)
            }
            .padding(MDSpacing.md)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mdBorder2, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

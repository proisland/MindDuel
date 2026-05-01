import SwiftUI

private enum HomeDestination: Identifiable {
    case profile
    case scoreboard
    case multiplayerHost
    case multiplayerJoin
    case activityList
    case multiplayerGame
    case activeGames
    var id: String {
        switch self {
        case .profile:         return "profile"
        case .scoreboard:      return "scoreboard"
        case .multiplayerHost: return "multiplayerHost"
        case .multiplayerJoin: return "multiplayerJoin"
        case .activityList:    return "activityList"
        case .multiplayerGame: return "multiplayerGame"
        case .activeGames:     return "activeGames"
        }
    }
}

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState
    @StateObject private var progression = ProgressionStore.shared
    @StateObject private var social      = SocialStore.shared
    @StateObject private var multiplayer = MultiplayerStore.shared
    @State private var activeMode: GameMode? = nil
    @State private var activeDestination: HomeDestination? = nil

    private var pendingBadge: Int { social.totalPendingCount }
    private var inviteBadge: Int  { multiplayer.pendingInviteCount }
    private var playingRooms: [MultiplayerRoom] { multiplayer.playingRooms }

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
                                level: progression.piLevel,
                                maxLevel: 20
                            ) { activeMode = .pi }

                            MDModeCard(
                                mode: .math,
                                score: progression.mathBestScore,
                                level: progression.mathLevel,
                                maxLevel: 20
                            ) { activeMode = .math }
                        }
                        .padding(.horizontal, MDSpacing.md)

                        // Rejoin banner (one or multiple active games)
                        if !playingRooms.isEmpty {
                            rejoinBanner
                                .padding(.horizontal, MDSpacing.md)
                        }

                        // Multiplayer card
                        multiplayerCard
                            .padding(.horizontal, MDSpacing.md)

                        // Scoreboard shortcut
                        scoreboardCard
                            .padding(.horizontal, MDSpacing.md)

                        // Recent activity — always visible
                        recentActivitySection
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
            case .profile:         ProfileView(username: username, onSignOut: { authState.signOut() })
            case .scoreboard:      ScoreboardView(ownUsername: username)
            case .multiplayerHost: MultiplayerLobbyView(ownUsername: username, startAsHost: true)
            case .multiplayerJoin: MultiplayerLobbyView(ownUsername: username, startAsHost: false)
            case .activityList:    ActivityListView(activity: multiplayer.recentActivity)
            case .multiplayerGame: MultiplayerGameView(ownUsername: username)
            case .activeGames:     ActiveGamesView(ownUsername: username)
            }
        }
    }

    // MARK: – Rejoin banner

    private var rejoinBanner: some View {
        let isMyTurn = multiplayer.hasMyTurnInBackground
        return Button {
            if playingRooms.count == 1 {
                multiplayer.rejoin(roomID: playingRooms[0].id)
                activeDestination = .multiplayerGame
            } else {
                activeDestination = .activeGames
            }
        } label: {
            HStack(spacing: MDSpacing.sm) {
                Circle().fill(Color.mdGreen).frame(width: 8, height: 8)
                if playingRooms.count == 1 {
                    Text(isMyTurn
                         ? String(localized: "rejoin_your_turn_action")
                         : String(localized: "rejoin_game_action"))
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdGreen)
                } else {
                    Text(String(format: String(localized: "rejoin_games_count_format"), playingRooms.count))
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdGreen)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mdGreen)
            }
            .padding(MDSpacing.md)
            .background(isMyTurn ? Color.mdGreen.opacity(0.15) : Color.mdGreenSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdGreen.opacity(isMyTurn ? 0.8 : 0.4), lineWidth: isMyTurn ? 1 : 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Multiplayer card

    private var multiplayerCard: some View {
        VStack(alignment: .leading, spacing: MDSpacing.sm) {
            HStack(spacing: MDSpacing.sm) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.mdPinkSoft).frame(width: 40, height: 40)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.mdPink)
                    }
                    if inviteBadge > 0 {
                        Text("\(inviteBadge)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(2)
                            .background(Color.mdRed)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "multiplayer_title"))
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "multiplayer_subtitle"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
            }

            HStack(spacing: MDSpacing.sm) {
                MDButton(.ghost, title: String(localized: "multiplayer_join_action")) {
                    activeDestination = .multiplayerJoin
                }
                .disabled(progression.isQuotaExhausted)
                MDButton(.primary, title: String(localized: "multiplayer_create_action")) {
                    activeDestination = .multiplayerHost
                }
                .disabled(progression.isQuotaExhausted)
            }
        }
        .padding(MDSpacing.md)
        .background(Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mdBorder2, lineWidth: 0.5))
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

    // MARK: – Recent activity section (always visible)

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: MDSpacing.sm) {
            HStack {
                Text(String(localized: "recent_activity_title"))
                    .mdStyle(.bodyMd)
                    .foregroundStyle(Color.mdText)
                Spacer()
                if !multiplayer.recentActivity.isEmpty {
                    Button { activeDestination = .activityList } label: {
                        Text(String(localized: "recent_activity_see_all"))
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if multiplayer.recentActivity.isEmpty {
                Text(String(localized: "no_activity_yet"))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, MDSpacing.md)
                    .background(Color.mdSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
            } else {
                VStack(spacing: MDSpacing.xs) {
                    ForEach(multiplayer.recentActivity.prefix(3)) { item in
                        activityRow(item)
                    }
                }
            }
        }
    }

    private func activityRow(_ item: MultiplayerActivityItem) -> some View {
        HStack(spacing: MDSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                MDAvatar(username: item.opponentUsername, size: .sm)
                Circle()
                    .fill(item.didWin ? Color.mdGreen : Color.mdRed)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.didWin
                     ? String(format: String(localized: "activity_won_format"), item.opponentUsername)
                     : String(format: String(localized: "activity_lost_format"), item.opponentUsername))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText)
                Text("\(item.mode == .pi ? String(localized: "mode_pi") : String(localized: "mode_math")) · +\(item.score)p")
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdText3)
            }
            Spacer()
            Text(item.timeAgoString)
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
    }
}

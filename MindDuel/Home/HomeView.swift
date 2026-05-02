import SwiftUI

private enum HomeDestination: Identifiable {
    case profile
    case scoreboard
    case multiplayerHost
    case multiplayerInvites
    case multiplayerLobbyJoined
    case activityList
    case multiplayerGame
    case activeGames
    var id: String {
        switch self {
        case .profile:                return "profile"
        case .scoreboard:             return "scoreboard"
        case .multiplayerHost:        return "multiplayerHost"
        case .multiplayerInvites:     return "multiplayerInvites"
        case .multiplayerLobbyJoined: return "multiplayerLobbyJoined"
        case .activityList:           return "activityList"
        case .multiplayerGame:        return "multiplayerGame"
        case .activeGames:            return "activeGames"
        }
    }
}

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState
    @ObservedObject private var progression = ProgressionStore.shared
    @ObservedObject private var social      = SocialStore.shared
    @ObservedObject private var multiplayer = MultiplayerStore.shared
    @State private var activeMode: GameMode? = nil
    @State private var activeDestination: HomeDestination? = nil
    @State private var resumeSoloRoomID: String? = nil

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
                                Text("\(username)")
                                    .mdStyle(.title)
                            }
                            Text(String(localized: "home_subtitle"))
                                .mdStyle(.body)
                                .foregroundStyle(Color.mdText2)
                        }
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.top, MDSpacing.sm)

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
                                maxLevel: 20,
                                compact: true
                            ) { startOrResume(.pi) }

                            MDModeCard(
                                mode: .math,
                                score: progression.mathBestScore,
                                level: progression.mathLevel,
                                maxLevel: 20,
                                compact: true
                            ) { startOrResume(.math) }

                            MDModeCard(
                                mode: .chemistry,
                                score: progression.chemBestScore,
                                level: progression.chemLevel,
                                maxLevel: 20,
                                compact: true
                            ) { startOrResume(.chemistry) }
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
        // Two intentional entry points to single-player play:
        //   • Mode cards here → PiGameView / MathGameView (this branch).
        //     Quick daily-practice flow with a polished round-end summary,
        //     replay button, and personal-best feedback.
        //   • Multiplayer card → MultiplayerLobbyView with one player.
        //     Same room model used for friends; less rich UX, but the user
        //     is in a flow where they may add opponents.
        // Both paths persist mid-session state via the shared
        // MultiplayerStore.backgroundRooms infra (`isStandaloneSolo` flag
        // distinguishes which UI to resume in — see ActiveGamesView).
        .fullScreenCover(item: $activeMode) { mode in
            switch mode {
            case .pi:        PiGameView(username: username, resumeRoomID: resumeSoloRoomID)
            case .math:      MathGameView(username: username, resumeRoomID: resumeSoloRoomID)
            case .chemistry: ChemistryGameView(username: username, resumeRoomID: resumeSoloRoomID)
            }
        }
        .onChange(of: activeMode) { mode in
            // Clear pending resume id once the cover is dismissed so the next
            // fresh open from a mode card doesn't accidentally try to resume.
            if mode == nil { resumeSoloRoomID = nil }
        }
        .fullScreenCover(item: $activeDestination) { dest in
            switch dest {
            case .profile:         ProfileView(username: username, onSignOut: { authState.signOut() })
            case .scoreboard:      ScoreboardView(ownUsername: username)
            case .multiplayerHost: MultiplayerLobbyView(ownUsername: username, startAsHost: true)
            case .multiplayerInvites:
                MultiplayerInvitesView(ownUsername: username) {
                    activeDestination = .multiplayerLobbyJoined
                }
            case .multiplayerLobbyJoined:
                MultiplayerLobbyView(ownUsername: username, startAsHost: false)
            case .activityList:    ActivityListView()
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
                let room = playingRooms[0]
                if room.isStandaloneSolo {
                    resumeSoloRoomID = room.id
                    activeMode = room.mode
                } else {
                    multiplayer.rejoin(roomID: room.id)
                    activeDestination = .multiplayerGame
                }
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
                    activeDestination = .multiplayerInvites
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

    /// #50: tapping a mode card while an unfinished standalone-solo session
    /// of that mode exists in backgroundRooms resumes it instead of starting
    /// a fresh round (which would shadow the saved progress).
    private func startOrResume(_ mode: GameMode) {
        if let existing = multiplayer.backgroundRooms.first(where: {
            $0.isStandaloneSolo && $0.mode == mode && $0.status == .playing
        }) {
            resumeSoloRoomID = existing.id
        } else {
            resumeSoloRoomID = nil
        }
        activeMode = mode
    }

    private func modeLabel(for mode: GameMode) -> String {
        switch mode {
        case .pi:        return String(localized: "mode_pi")
        case .math:      return String(localized: "mode_math")
        case .chemistry: return String(localized: "mode_chemistry")
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
                Text(String(format: String(localized: "activity_score_format"),
                            modeLabel(for: item.mode),
                            item.score))
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

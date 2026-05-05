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
    case allModes
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
        case .allModes:               return "allModes"
        }
    }
}

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState
    @ObservedObject private var progression = ProgressionStore.shared
    @ObservedObject private var social      = SocialStore.shared
    @ObservedObject private var multiplayer = MultiplayerStore.shared
    @ObservedObject private var prefs       = ModePreferences.shared
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
                centeredHeader

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
                        .padding(.top, MDSpacing.xs)

                        // Quota warning banner
                        if progression.isNearQuota {
                            QuotaBanner(
                                used: progression.dailyUsed,
                                total: ProgressionStore.dailyQuota
                            )
                            .padding(.horizontal, MDSpacing.md)
                        }

                        favoritesSection
                        quickAccessSection

                        // Rejoin banner (one or multiple active games)
                        if !playingRooms.isEmpty {
                            rejoinBanner
                                .padding(.horizontal, MDSpacing.md)
                        }

                        // Multiplayer card (redesigned: 52px icon, pill buttons)
                        multiplayerCard
                            .padding(.horizontal, MDSpacing.md)

                        // Scoreboard shortcut (redesigned)
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
            case .pi:            PiGameView(username: username, resumeRoomID: resumeSoloRoomID)
            case .math:          MathGameView(username: username, resumeRoomID: resumeSoloRoomID)
            case .chemistry:     ChemistryGameView(username: username, resumeRoomID: resumeSoloRoomID)
            case .geography:     GeographyGameView(username: username, resumeRoomID: resumeSoloRoomID)
            case .brainTraining: BrainTrainingGameView(username: username)
            }
        }
        .onChange(of: activeMode) { mode in
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
            case .allModes:        AllModesSheet(onPlay: { startOrResume($0) })
            }
        }
    }

    // MARK: – Centered header

    private var centeredHeader: some View {
        ZStack {
            Text("MindDuel")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.mdText)

            HStack {
                Spacer()
                Button { activeDestination = .profile } label: {
                    ZStack(alignment: .topTrailing) {
                        MDAvatar(username: username, size: .sm)
                        if pendingBadge > 0 {
                            Circle()
                                .fill(Color.mdRed)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Color.mdBg, lineWidth: 2))
                                .offset(x: 1, y: -1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MDSpacing.md)
        .frame(height: 44)
    }

    // MARK: – Favorites

    private var favoritesSection: some View {
        let featured = prefs.featured(count: 4)
        let title = prefs.favorites.isEmpty
            ? String(localized: "favorites_section_most_played")
            : String(localized: "favorites_section_title")
        return VStack(alignment: .leading, spacing: MDSpacing.sm) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.mdText)
                Spacer()
                Button { activeDestination = .allModes } label: {
                    Text(String(localized: "favorites_see_all"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.mdAccent)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(featured, id: \.self) { mode in
                    MDFeaturedCard(
                        mode: mode,
                        score: progression.bestScore(for: mode),
                        level: progression.level(for: mode),
                        action: { startOrResume(mode) }
                    )
                }
            }
        }
        .padding(.horizontal, MDSpacing.md)
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            Text(String(localized: "quick_access_title"))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.mdText)
                .padding(.horizontal, MDSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(prefs.order, id: \.self) { mode in
                        MDQuickPill(mode: mode) { startOrResume(mode) }
                    }
                }
                .padding(.horizontal, MDSpacing.md)
                .padding(.vertical, 2)
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

    // MARK: – Multiplayer card (redesigned per design)

    private var multiplayerCard: some View {
        VStack(alignment: .leading, spacing: MDSpacing.md) {
            HStack(spacing: MDSpacing.sm) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.42, green: 0.10, blue: 0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    if inviteBadge > 0 {
                        Button { activeDestination = .multiplayerInvites } label: {
                            Text("\(inviteBadge)")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(minWidth: 20, minHeight: 20)
                                .padding(.horizontal, 3)
                                .background(Color.mdRed)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.mdSurface, lineWidth: 2.5))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 7, y: -7)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "multiplayer_title"))
                        .font(.system(size: 15, weight: .heavy))
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
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    // MARK: – Scoreboard card (redesigned)

    private var scoreboardCard: some View {
        Button { activeDestination = .scoreboard } label: {
            HStack(spacing: MDSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.12, green: 0.13, blue: 0.38))
                        .frame(width: 52, height: 52)
                    HStack(alignment: .bottom, spacing: 4) {
                        Capsule().fill(Color.mdAccent).frame(width: 6, height: 12)
                        Capsule().fill(Color.mdAccent).frame(width: 6, height: 17)
                        Capsule().fill(Color.mdAccent).frame(width: 6, height: 22)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "scoreboard_title"))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "scoreboard_subtitle"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mdText3)
            }
            .padding(MDSpacing.md)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mdBorder2, lineWidth: 0.5))
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
                VStack(spacing: 0) {
                    let recent = Array(multiplayer.recentActivity.prefix(3))
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, item in
                        activityRow(item)
                        if idx < recent.count - 1 {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
    }

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
        mode.localizedTitle
    }

    private func activityRow(_ item: MultiplayerActivityItem) -> some View {
        HStack(spacing: MDSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                MDAvatar(username: item.opponentUsername, size: .sm)
                Circle()
                    .fill(item.didWin ? Color.mdGreen : Color.mdRed)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.mdBg, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(item.didWin
                         ? String(localized: "activity_won_prefix")
                         : String(localized: "activity_lost_prefix"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.mdText)
                    Text("@\(item.opponentUsername)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.mdAccent)
                }
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
        .padding(.vertical, 10)
    }
}

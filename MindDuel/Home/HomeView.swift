import SwiftUI

private struct GameModeRoute: Hashable {
    let mode: GameMode
    let resumeRoomID: String?
    var isPractice: Bool = false
    var practiceStartLevel: Int = 1
}

private struct ServerModeRoute: Hashable {
    let serverMode: ServerMode
    let resumeRoomID: String?
}

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
    @ObservedObject private var progression    = ProgressionStore.shared
    @ObservedObject private var social         = SocialStore.shared
    @ObservedObject private var multiplayer    = MultiplayerStore.shared
    @ObservedObject private var prefs          = ModePreferences.shared
    @ObservedObject private var modeCache      = ModeConfigCache.shared
    @ObservedObject private var dailyChallenge = DailyChallengeStore.shared
    @State private var gamePath = NavigationPath()
    @State private var activeDestination: HomeDestination? = nil
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var practiceMode: GameMode? = nil
    @State private var pendingGameMode: GameMode? = nil
    @State private var showUpgradeComingSoon = false
    @AppStorage("game.difficulty") private var difficultyRaw: String = "normal"
    private var difficulty: GameDifficulty { GameDifficulty(rawValue: difficultyRaw) ?? .normal }

    private var pendingBadge: Int { social.totalPendingCount }
    private var inviteBadge: Int  { multiplayer.pendingInviteCount }

    private enum FeedRow: Identifiable {
        case game(MultiplayerActivityItem)
        case social(SocialFeedItem)
        var id: String {
            switch self {
            case .game(let g):   return g.id.uuidString
            case .social(let s): return s.id
            }
        }
        var timestamp: Date {
            switch self {
            case .game(let g):   return g.timestamp
            case .social(let s): return s.createdAt
            }
        }
    }

    private var mergedFeed: [FeedRow] {
        let gameRows   = multiplayer.recentActivity.map { FeedRow.game($0) }
        let socialRows = social.socialFeed.map { FeedRow.social($0) }
        return (gameRows + socialRows).sorted { $0.timestamp > $1.timestamp }
    }
    private var playingRooms: [MultiplayerRoom] { multiplayer.playingRooms }

    var body: some View {
        NavigationStack(path: $gamePath) {
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
                                    total: ProgressionStore.dailyQuota,
                                    onUpgrade: { showUpgradeComingSoon = true }
                                )
                                .padding(.horizontal, MDSpacing.md)
                            }

                            favoritesSection

                            // Daily challenge card
                            if let challenge = dailyChallenge.challenge {
                                DailyChallengeCard(challenge: challenge) {
                                    if let gm = GameMode(slug: challenge.mode.slug) {
                                        startOrResume(gm)
                                    } else if let sm = modeCache.serverOnlyModes.first(where: { $0.slug == challenge.mode.slug }) {
                                        startOrResumeServer(sm)
                                    }
                                }
                                .padding(.horizontal, MDSpacing.md)
                            }

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
            .onAppear {
                progression.checkResetQuota()
                if !hasSeenOnboarding { showOnboarding = true }
                Task { await DailyChallengeStore.shared.fetch() }
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
            case .allModes:
                AllModesSheet(
                    onPlay: { startOrResume($0) },
                    onPlayServerMode: { startOrResumeServer($0) },
                    onPractice: { startPractice($0) }
                )
            }
        }
        .navigationDestination(for: GameModeRoute.self) { route in
            soloGameView(route: route)
                .toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(for: ServerModeRoute.self) { route in
            KnowledgeGameView(serverMode: route.serverMode, username: username,
                              resumeRoomID: route.resumeRoomID)
                .toolbar(.hidden, for: .navigationBar)
        }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .sheet(item: $practiceMode) { mode in
            PracticeSetupSheet(mode: mode) { startLevel in
                gamePath.append(GameModeRoute(mode: mode, resumeRoomID: nil,
                                             isPractice: true, practiceStartLevel: startLevel))
            }
        }
        .sheet(item: $pendingGameMode) { mode in
            DifficultyPickerSheet(difficulty: $difficultyRaw) {
                pendingGameMode = nil
                gamePath.append(GameModeRoute(mode: mode, resumeRoomID: nil))
            }
        }
        .alert(
            String(localized: "upgrade_coming_soon_title"),
            isPresented: $showUpgradeComingSoon
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(String(localized: "upgrade_coming_soon_message"))
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
        let title = prefs.favorites.isEmpty && prefs.serverFavorites.isEmpty
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

            // Non-lazy 2-column grid — avoids LazyVGrid's intermittent
            // first-row rendering glitch on iOS 16/17.
            let row1 = Array(featured.prefix(2))
            let row2 = Array(featured.dropFirst(2).prefix(2))
            VStack(spacing: 10) {
                if !row1.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(row1) { featuredCardView(for: $0) }
                        if row1.count < 2 { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
                if !row2.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(row2) { featuredCardView(for: $0) }
                        if row2.count < 2 { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
        .padding(.horizontal, MDSpacing.md)
    }

    // MARK: – Rejoin banner

    private var rejoinBanner: some View {
        let isMyTurn = multiplayer.hasMyTurnInBackground
        return Button {
            if playingRooms.count == 1 {
                let room = playingRooms[0]
                if room.isStandaloneSolo, let slug = room.serverModeSlug,
                   let serverMode = modeCache.serverOnlyModes.first(where: { $0.slug == slug }) {
                    gamePath.append(ServerModeRoute(serverMode: serverMode, resumeRoomID: room.id))
                } else if room.isStandaloneSolo, room.serverModeSlug == nil {
                    let mode = room.mode
                    gamePath.append(GameModeRoute(mode: mode, resumeRoomID: room.id))
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
                if !mergedFeed.isEmpty {
                    Button { activeDestination = .activityList } label: {
                        Text(String(localized: "recent_activity_see_all"))
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            let rows = Array(mergedFeed.prefix(3))
            if rows.isEmpty {
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
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                        Group {
                            switch row {
                            case .game(let item):   activityRow(item)
                            case .social(let item): socialActivityRow(item)
                            }
                        }
                        if idx < rows.count - 1 {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func featuredCardView(for mode: AnyMode) -> some View {
        switch mode {
        case .known(let gm):
            MDFeaturedCard(
                mode: gm,
                score: progression.bestScore(for: gm),
                level: progression.level(for: gm),
                streak: progression.currentStreak(for: gm),
                action: { startOrResume(gm) }
            )
            .contextMenu {
                Button { startOrResume(gm) } label: {
                    Label(String(localized: "play_normal_action"), systemImage: "play.fill")
                }
                if gm == .pi || gm == .math {
                    Button { startPractice(gm) } label: {
                        Label(String(localized: "practice_round_action"), systemImage: "dumbbell.fill")
                    }
                }
            }
        case .server(let sm):
            MDServerFeaturedCard(
                serverMode: sm,
                score: progression.bestScore(forSlug: sm.slug),
                level: progression.level(forSlug: sm.slug),
                action: { startOrResumeServer(sm) }
            )
        }
    }

    private func startOrResume(_ mode: GameMode) {
        let resumeRoomID = multiplayer.backgroundRooms.first(where: {
            $0.isStandaloneSolo && $0.mode == mode && $0.serverModeSlug == nil && $0.status == .playing
        })?.id
        if resumeRoomID != nil {
            gamePath.append(GameModeRoute(mode: mode, resumeRoomID: resumeRoomID))
        } else {
            pendingGameMode = mode
        }
    }

    private func startPractice(_ mode: GameMode) {
        practiceMode = mode
    }

    private func startOrResumeServer(_ serverMode: ServerMode) {
        let resumeRoomID = multiplayer.backgroundRooms.first(where: {
            $0.isStandaloneSolo && $0.serverModeSlug == serverMode.slug && $0.status == .playing
        })?.id
        gamePath.append(ServerModeRoute(serverMode: serverMode, resumeRoomID: resumeRoomID))
    }

    @ViewBuilder
    private func soloGameView(route: GameModeRoute) -> some View {
        switch route.mode {
        case .pi:
            PiGameView(username: username, resumeRoomID: route.resumeRoomID,
                       isPractice: route.isPractice, practiceStartDigit: route.practiceStartLevel)
        case .math:
            MathGameView(username: username, resumeRoomID: route.resumeRoomID,
                         isPractice: route.isPractice, practiceStartLevel: route.practiceStartLevel)
        default:
            StandardGameView(mode: route.mode, username: username, resumeRoomID: route.resumeRoomID)
        }
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

    @ViewBuilder
    private func socialActivityRow(_ item: SocialFeedItem) -> some View {
        HStack(spacing: MDSpacing.sm) {
            switch item.type {
            case .newFriend:
                ZStack(alignment: .bottomTrailing) {
                    MDAvatar(username: item.user1?.username ?? "?", size: .sm)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.mdGreen)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.mdBg, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if item.isMe == true {
                        HStack(spacing: 3) {
                            Text(String(localized: "activity_friend_you"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdText)
                            Text("@\(item.user2?.username ?? "?")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdAccent)
                            Text(String(localized: "activity_friend_suffix"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdText)
                        }
                    } else {
                        HStack(spacing: 3) {
                            Text("@\(item.user1?.username ?? "?")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdAccent)
                            Text(String(localized: "activity_friend_and"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdText)
                            Text("@\(item.user2?.username ?? "?")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdAccent)
                            Text(String(localized: "activity_friend_suffix"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdText)
                        }
                    }
                }
            case .streak:
                ZStack(alignment: .bottomTrailing) {
                    MDAvatar(username: item.user?.username ?? "?", size: .sm)
                    Text("🔥")
                        .font(.system(size: 11))
                        .offset(x: 3, y: 3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        if item.isMine == true {
                            Text(String(localized: "activity_streak_you"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdText)
                        } else {
                            Text("@\(item.user?.username ?? "?")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mdAccent)
                        }
                        Text(String(format: String(localized: "activity_streak_days_format"),
                                    item.streakCount ?? 0))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.mdText)
                    }
                    if let modeName = item.modeName {
                        Text(String(format: String(localized: "activity_streak_mode_format"), modeName))
                            .mdStyle(.micro)
                            .foregroundStyle(Color.mdText3)
                    }
                }
            case .unknown:
                EmptyView()
            }
            Spacer()
            Text(UserProfile.relativeTime(item.createdAt))
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
        }
        .padding(.vertical, 10)
    }
}

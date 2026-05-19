import SwiftUI
import CoreLocation

struct ScoreboardView: View {
    let ownUsername: String
    @ObservedObject private var social = SocialStore.shared
    @ObservedObject private var progression = ProgressionStore.shared
    @ObservedObject private var modePrefs = ModePreferences.shared
    @ObservedObject private var locationAuth = LocationAuthStore.shared
    @ObservedObject private var scoreboardStore = ScoreboardStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0          // default: Venner (#76)
    @State private var selectedProfile: UserProfile? = nil
    @State private var searchText = ""
    @State private var scoreMode: AnyMode = .known(.pi)
    @State private var useTotalScore: Bool = true
    @State private var timeRange: TimeRange = .today

    private enum TimeRange: String, CaseIterable, Identifiable {
        case today, week, all
        var id: String { rawValue }
        var labelKey: String.LocalizationValue {
            switch self {
            case .today: return "scoreboard_time_today"
            case .week:  return "scoreboard_time_week"
            case .all:   return "scoreboard_time_all"
            }
        }
    }

    private var ownEntry: UserProfile {
        UserProfile(
            id: "me",
            username: ownUsername,
            piScore: progression.piBestScore,
            mathScore: progression.mathBestScore,
            chemScore: progression.chemBestScore,
            geoScore: progression.geoBestScore,
            brainScore: progression.brainBestScore,
            scienceScore: progression.scienceBestScore,
            historyScore: progression.historyBestScore,
            physicsScore: progression.physicsBestScore,
            sportScore: progression.sportBestScore,
            grammarScore: progression.grammarBestScore,
            piLevel: progression.piLevel,
            mathLevel: progression.mathLevel,
            chemLevel: progression.chemLevel,
            geoLevel: progression.geoLevel,
            brainLevel: progression.brainLevel,
            scienceLevel: progression.scienceLevel,
            historyLevel: progression.historyLevel,
            physicsLevel: progression.physicsLevel,
            sportLevel: progression.sportLevel,
            grammarLevel: progression.grammarLevel,
            roundsPlayed: progression.totalRoundsPlayed,
            age: nil, city: nil,
            memberSince: "april 2025",
            lastActive: String(localized: "last_active_now"),
            isFriend: false,
            isFlagged: progression.isFlagged
        )
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "scoreboard_title"), leadingAction: { dismiss() }) {
                    EmptyView()
                }

                segmentedControl
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.top, MDSpacing.md)

                scoreModeToggle
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.top, MDSpacing.xs)

                timeRangeSelector
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.top, MDSpacing.xs)

                // Search bar (shown on Lokalt and Globalt tabs)
                if selectedTab != 0 {
                    searchBar
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.top, MDSpacing.sm)
                }

                leaderboardList
            }
        }
        .fullScreenCover(item: $selectedProfile) { profile in
            OtherProfileView(profile: profile, ownUsername: ownUsername)
        }
        .task { await scoreboardStore.refresh(slug: useTotalScore ? nil : scoreMode.slug) }
        .onChange(of: scoreMode) { mode in
            Task { await scoreboardStore.refresh(slug: useTotalScore ? nil : mode.slug) }
        }
        .onChange(of: useTotalScore) { total in
            Task { await scoreboardStore.refresh(slug: total ? nil : scoreMode.slug) }
        }
    }

    // MARK: – Time range selector (#76)
    //
    // Mock data has no per-day timestamps so all three ranges currently
    // surface the same entries. The control is wired up so that when
    // server-backed scoring lands the filter just needs to be applied in
    // `score(for:profile)` / `buildRanked`.

    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                let active = timeRange == range
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { timeRange = range }
                } label: {
                    Text(String(localized: range.labelKey))
                        .font(.system(size: 12, weight: active ? .heavy : .medium))
                        .foregroundStyle(active ? Color.mdText : Color.mdText3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(active ? Color.mdSurface2 : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.mdBgDeep)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: – Score mode toggle

    private var scoreModeToggle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Total chip (default)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { useTotalScore = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sum")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(useTotalScore ? Color.mdAccent : Color.mdText3)
                        Text(String(localized: "scoreboard_total_label"))
                            .font(.system(size: 12, weight: useTotalScore ? .heavy : .medium))
                            .foregroundStyle(useTotalScore ? Color.mdText : Color.mdText3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(useTotalScore ? Color.mdAccent.opacity(0.13) : Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            useTotalScore ? Color.mdAccent.opacity(0.7) : Color.white.opacity(0.08),
                            lineWidth: 1.5
                        )
                    )
                }
                .buttonStyle(.plain)

                ForEach(modePrefs.activeCombinedOrder) { mode in
                    let selected = !useTotalScore && scoreMode == mode
                    let accent = modeAccentColor(mode)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            useTotalScore = false
                            scoreMode = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            anyModeGlyph(mode, size: 13, weight: .bold, color: accent)
                            Text(modeLabel(mode))
                                .font(.system(size: 12, weight: selected ? .heavy : .medium))
                                .foregroundStyle(selected ? Color.mdText : Color.mdText3)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selected ? accent.opacity(0.13) : Color.white.opacity(0.05))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selected ? accent.opacity(0.7) : Color.white.opacity(0.08),
                                lineWidth: 1.5
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func anyModeGlyph(_ mode: AnyMode, size: CGFloat, weight: Font.Weight, color: Color) -> some View {
        switch mode {
        case .known(let gm):  ModeGlyph(mode: gm, size: size, weight: weight, color: color)
        case .server(let sm): ServerModeGlyph(iconSymbol: sm.iconSymbol, size: size, weight: weight, color: color)
        }
    }

    private func modeLabel(_ mode: AnyMode) -> String {
        switch mode {
        case .known(let gm): return scoreboardLabel(for: gm)
        case .server(let sm): return sm.name
        }
    }

    private func modeAccentColor(_ mode: AnyMode) -> Color {
        switch mode {
        case .known(let gm):  return gm.accentColor
        case .server(let sm): return sm.accentColor
        }
    }

    private func scoreboardLabel(for mode: GameMode) -> String {
        switch mode {
        case .pi:            return String(localized: "mode_pi")
        case .math:          return String(localized: "mode_math")
        case .chemistry:     return String(localized: "mode_chemistry")
        case .geography:     return String(localized: "mode_geography")
        case .brainTraining: return String(localized: "mode_brain_training")
        case .science:       return String(localized: "mode_science")
        case .history:       return String(localized: "mode_history")
        case .physics:       return String(localized: "mode_physics")
        case .sport:         return String(localized: "mode_sport")
        case .grammar:       return String(localized: "mode_grammar")
        }
    }

    private func effectiveScore(for profile: UserProfile) -> Int {
        if useTotalScore {
            if profile.username == ownUsername {
                return max(profile.apiScore, profile.totalScore)
            }
            return profile.apiScore > 0 ? profile.apiScore : profile.totalScore
        }
        switch scoreMode {
        case .known(let gm): return profile.score(for: gm)
        case .server:        return profile.apiScore
        }
    }

    // MARK: – Segmented control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, label in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = i
                        searchText = ""
                        // Friends defaults to Today; the wider boards default
                        // to All-time so an empty-day mock doesn't look broken.
                        timeRange = (i == 0) ? .today : .all
                    }
                } label: {
                    Text(label)
                        .mdStyle(.bodyMd)
                        .foregroundStyle(selectedTab == i ? Color.mdText : Color.mdText3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MDSpacing.xs)
                        .background(selectedTab == i ? Color.mdSurface2 : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.mdBgDeep)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tabs: [String] {
        [
            String(localized: "scoreboard_friends_tab"),
            String(localized: "scoreboard_local_tab"),
            String(localized: "scoreboard_global_tab"),
        ]
    }

    // MARK: – Search bar

    private var searchBar: some View {
        HStack(spacing: MDSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.mdText3)
            TextField(String(localized: "search_username_placeholder"), text: $searchText)
                .mdStyle(.bodyMd)
                .foregroundStyle(Color.mdText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mdText3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MDSpacing.sm)
        .padding(.vertical, MDSpacing.xs)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    // MARK: – List

    private var filteredGlobalEntries: [UserProfile] {
        let base = scoreboardStore.globalEntries.map { scoreboardStore.userProfile(for: $0) }
        return searchText.isEmpty
            ? base
            : base.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: MDSpacing.xs) {
                if selectedTab == 0 {
                    friendsSection
                } else if selectedTab == 1 && !isLocationAuthorized {
                    locationPermissionPrompt
                } else {
                    globalSection(entries: filteredGlobalEntries)
                }
            }
            .id(selectedTab)          // force full re-render on tab switch
            .padding(.horizontal, MDSpacing.md)
            .padding(.top, MDSpacing.md)
            .padding(.bottom, MDSpacing.xl)
        }
    }

    // MARK: – Location permission (#77)

    private var isLocationAuthorized: Bool { locationAuth.isAuthorized }

    private var locationPermissionPrompt: some View {
        // First time (.notDetermined): trigger native prompt directly. iOS only
        // adds the app to Innstillinger → Personvern → Posisjonstjenester after
        // the prompt has been shown once, so going straight to Settings before
        // that leaves the user on a page without a Location row.
        let needsPrompt = locationAuth.status == .notDetermined
        let titleKey: String.LocalizationValue = needsPrompt
            ? "scoreboard_local_request_permission_title"
            : "scoreboard_local_no_permission_title"
        let bodyKey: String.LocalizationValue = needsPrompt
            ? "scoreboard_local_request_permission_body"
            : "scoreboard_local_no_permission_body"
        let actionKey: String.LocalizationValue = needsPrompt
            ? "scoreboard_share_location_action"
            : "scoreboard_open_location_settings"

        return VStack(spacing: MDSpacing.sm) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.mdAmber)
            Text(String(localized: titleKey))
                .mdStyle(.heading)
                .foregroundStyle(Color.mdText)
            Text(String(localized: bodyKey))
                .mdStyle(.body)
                .foregroundStyle(Color.mdText2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            MDButton(.primary, title: String(localized: actionKey)) {
                if needsPrompt {
                    locationAuth.requestPermission()
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(MDSpacing.lg)
    }

    // MARK: – Friends section

    @ViewBuilder
    private var friendsSection: some View {
        if social.pendingRequests.isEmpty && social.friends.isEmpty {
            emptyFriendsView
        } else {
            if !social.pendingRequests.isEmpty {
                sectionHeader(String(localized: "pending_requests_label"))
                ForEach(social.pendingRequests) { req in
                    FriendRequestRow(profile: req) {
                        social.acceptRequest(from: req.username)
                    } onDecline: {
                        social.declineRequest(from: req.username)
                    }
                }
            }

            sectionHeader(String(localized: "scoreboard_friends_tab"))
            rankedFriendsSection

            // Weekly friends leaderboard — shown only when ≥5 friends
            if let weekly = scoreboardStore.weeklyFriendsResponse,
               weekly.friendCount >= weekly.minFriends,
               !weekly.entries.isEmpty {
                sectionHeader(String(localized: "scoreboard_weekly_friends_title"))
                ForEach(weekly.entries) { entry in
                    weeklyLeaderboardRow(entry: entry)
                }
            }

            // Friend suggestions — shown at the bottom when available
            if !social.friendSuggestions.isEmpty {
                sectionHeader(String(localized: "friend_suggestions_section_title"))
                ForEach(social.friendSuggestions.prefix(5)) { suggestion in
                    suggestionRow(suggestion: suggestion)
                }
            }
        }
    }

    @ViewBuilder
    private var rankedFriendsSection: some View {
        let apiEntries = scoreboardStore.friendEntries.map { scoreboardStore.userProfile(for: $0) }
        let ranked = buildRanked(apiEntries.isEmpty ? social.friends : apiEntries, own: ownEntry)
        if ranked.isEmpty {
            Text(String(localized: "no_friends_yet"))
                .mdStyle(.body)
                .foregroundStyle(Color.mdText3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, MDSpacing.lg)
        } else {
            ForEach(ranked, id: \.profile.id) { item in
                leaderboardRow(rank: item.rank, profile: item.profile, isOwn: item.isOwn)
            }
        }
    }

    @ViewBuilder
    private func weeklyLeaderboardRow(entry: WeeklyLeaderboardEntry) -> some View {
        HStack(spacing: MDSpacing.sm) {
            Text("#\(entry.rank)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.mdText3)
                .frame(width: 28, alignment: .center)
            Text(entry.avatarEmoji)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isMe ? String(localized: "you_label") : entry.username)
                    .font(.system(size: 13, weight: entry.isMe ? .heavy : .semibold))
                    .foregroundStyle(entry.isMe ? Color.mdAccent : Color.mdText)
                Text(String(format: String(localized: "scoreboard_rounds_format"), entry.roundCount))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mdText3)
            }
            Spacer()
            Text(formatPoints(entry.avgScore))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.mdAccent)
        }
        .padding(MDSpacing.sm)
        .background(entry.isMe ? Color.mdAccent.opacity(0.08) : Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    // MARK: – Global section

    @ViewBuilder
    private func globalSection(entries: [UserProfile]) -> some View {
        if entries.isEmpty {
            Text("\(searchText) …")
                .mdStyle(.body)
                .foregroundStyle(Color.mdText3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, MDSpacing.lg)
        } else {
            ForEach(buildRanked(entries, own: ownEntry), id: \.profile.id) { item in
                leaderboardRow(rank: item.rank, profile: item.profile, isOwn: item.isOwn)
            }
        }
    }

    // MARK: – Suggestion row

    @ViewBuilder
    private func suggestionRow(suggestion: FriendSuggestion) -> some View {
        HStack(spacing: MDSpacing.sm) {
            MDAvatar(username: suggestion.username, size: .sm,
                     customEmoji: suggestion.avatarEmoji == "🧠" ? nil : suggestion.avatarEmoji,
                     avatarUrl: suggestion.avatarUrl)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MDSpacing.xxs) {
                    Text(suggestion.username)
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                        .lineLimit(1)
                    if suggestion.isPremium {
                        MDPillTag(label: String(localized: "premium_label"), variant: .amber)
                    }
                }
                if suggestion.mutualFriendsCount > 0 {
                    Text(String(format: String(localized: "friend_suggestion_mutual_format"),
                                suggestion.mutualFriendsCount))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                }
            }
            Spacer()
            if social.sentRequestUsernames.contains(suggestion.username) {
                Text(String(localized: "friend_request_pending_short"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mdText3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
            } else {
                Button {
                    social.sendFriendRequest(to: suggestion.username)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(localized: "add_friend_short_action"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.mdAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.mdAccentSoft))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    // MARK: – Shared helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .mdStyle(.micro)
            .foregroundStyle(Color.mdText3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, MDSpacing.xs)
    }

    private var emptyFriendsView: some View {
        VStack(spacing: MDSpacing.sm) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundStyle(Color.mdText3)
            Text(String(localized: "no_friends_yet"))
                .mdStyle(.body)
                .foregroundStyle(Color.mdText3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MDSpacing.xxl)
    }

    @ViewBuilder
    private func leaderboardRow(rank: Int, profile: UserProfile, isOwn: Bool) -> some View {
        Button {
            if !isOwn { selectedProfile = profile }
        } label: {
            HStack(spacing: MDSpacing.sm) {
                Group {
                    if let trophy = trophyColor(forRank: rank) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(trophy)
                    } else {
                        Text("\(rank)")
                            .mdStyle(.bodyMd)
                            .foregroundStyle(Color.mdText3)
                    }
                }
                .frame(width: 24, alignment: .center)

                MDAvatar(username: profile.username, size: .sm,
                         customEmoji: profile.avatarEmoji == "🧠" ? nil : profile.avatarEmoji,
                         avatarUrl: profile.avatarUrl)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: MDSpacing.xxs) {
                        Text("\(profile.username)")
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if profile.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.mdRed)
                        }
                    }
                    if let age = profile.age, let city = profile.city {
                        Text("\(age) · \(city)")
                            .mdStyle(.micro)
                            .foregroundStyle(Color.mdText3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(effectiveScore(for: profile)) \(String(localized: "points_word"))")
                    .mdStyle(.bodyMd)
                    .foregroundStyle((!isOwn ? trophyColor(forRank: rank) : nil) ?? Color.mdText2)
                    .lineLimit(1)
                    .frame(width: 84, alignment: .trailing)

                Group {
                    if !isOwn { addFriendButton(for: profile) }
                    else { Color.clear }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, MDSpacing.md)
            .padding(.vertical, MDSpacing.sm)
            .background(rowBackground(rank: rank, isOwn: isOwn))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(isOwn)
    }

    @ViewBuilder
    private func addFriendButton(for profile: UserProfile) -> some View {
        if social.friendUsernames.contains(profile.username) {
            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.mdGreen)
        } else if social.sentRequestUsernames.contains(profile.username) {
            Text(String(localized: "friend_request_pending_short"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mdText3)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.05)))
        } else {
            Button {
                social.sendFriendRequest(to: profile.username)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(localized: "add_friend_short_action"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.mdAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.mdAccentSoft))
            }
            .buttonStyle(.plain)
        }
    }

    private func rowBackground(rank: Int, isOwn: Bool) -> Color {
        if isOwn        { return .mdAccentSoft }
        if rank == 1    { return .mdAmberSoft }
        return .mdSurface2
    }

    /// Trophy tint for top-3 ranks (#85). Bronze for 3rd uses a brown-ish tone
    /// blended from amber+red so it reads distinct from gold.
    private func trophyColor(forRank rank: Int) -> Color? {
        switch rank {
        case 1: return Color(red: 1.00, green: 0.80, blue: 0.20)   // gold
        case 2: return Color(red: 0.78, green: 0.78, blue: 0.82)   // silver
        case 3: return Color(red: 0.70, green: 0.43, blue: 0.20)   // bronze
        default: return nil
        }
    }

    // MARK: – Rank builder

    private struct RankedEntry {
        let rank: Int
        let profile: UserProfile
        let isOwn: Bool
    }

    private func buildRanked(_ list: [UserProfile], own: UserProfile) -> [RankedEntry] {
        var combined = list
        if !combined.contains(where: { $0.username == own.username }) {
            // Own user is not in the API list — inject local entry.
            combined.append(own)
        }
        // If own user IS in the list (from API), their per-mode scores are 0
        // but apiScore is correct. Patch in the local per-mode scores so both
        // Total (apiScore) and per-mode tabs work correctly for the own row.
        combined = combined.map { p -> UserProfile in
            guard p.username == own.username, p.apiScore > 0 else { return p }
            var patched = own          // bring in per-mode local scores
            patched.apiScore = p.apiScore  // keep the server-side avgScore
            return patched
        }
        return combined
            .sorted { effectiveScore(for: $0) > effectiveScore(for: $1) }
            .enumerated()
            .map { idx, p in RankedEntry(rank: idx + 1, profile: p, isOwn: p.username == own.username) }
    }
}

// MARK: – Friend request row

private struct FriendRequestRow: View {
    let profile: UserProfile
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: MDSpacing.sm) {
            MDAvatar(username: profile.username, size: .sm,
                     avatarUrl: profile.avatarUrl)
            Text("\(profile.username)")
                .mdStyle(.caption)
                .foregroundStyle(Color.mdText)
            Spacer()
            MDButton(.ghost, title: String(localized: "decline_action"), action: onDecline)
                .frame(width: 68)
            MDButton(.primary, title: String(localized: "accept_action"), action: onAccept)
                .frame(width: 68)
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }
}

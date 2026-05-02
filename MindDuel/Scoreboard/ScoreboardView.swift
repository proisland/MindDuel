import SwiftUI

struct ScoreboardView: View {
    let ownUsername: String
    @ObservedObject private var social = SocialStore.shared
    @ObservedObject private var progression = ProgressionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 2          // default: Globalt
    @State private var selectedProfile: UserProfile? = nil
    @State private var searchText = ""
    @State private var scoreMode: GameMode = .pi

    private var ownEntry: UserProfile {
        UserProfile(
            id: "me",
            username: ownUsername,
            piScore: progression.piBestScore,
            mathScore: progression.mathBestScore,
            chemScore: progression.chemBestScore,
            geoScore: progression.geoBestScore,
            piLevel: progression.piLevel,
            mathLevel: progression.mathLevel,
            chemLevel: progression.chemLevel,
            geoLevel: progression.geoLevel,
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

                // Search bar (shown on Lokalt and Globalt tabs)
                if selectedTab != 0 {
                    searchBar
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.top, MDSpacing.sm)
                }

                leaderboardList
            }
        }
        .sheet(item: $selectedProfile) { profile in
            OtherProfileView(profile: profile, ownUsername: ownUsername)
        }
    }

    // MARK: – Score mode toggle

    private var scoreModeToggle: some View {
        HStack(spacing: 0) {
            ForEach([GameMode.pi, GameMode.math, GameMode.chemistry, GameMode.geography]) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { scoreMode = mode }
                } label: {
                    Text(scoreboardLabel(for: mode))
                        .mdStyle(.caption)
                        .foregroundStyle(scoreMode == mode ? Color.mdText : Color.mdText3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(scoreMode == mode ? Color.mdSurface2 : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.mdBgDeep)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scoreboardLabel(for mode: GameMode) -> String {
        switch mode {
        case .pi:        return String(localized: "scoreboard_pi_mode")
        case .math:      return String(localized: "scoreboard_math_mode")
        case .chemistry: return String(localized: "mode_chemistry")
        case .geography: return String(localized: "mode_geography")
        }
    }

    private func score(for profile: UserProfile, mode: GameMode) -> Int {
        switch mode {
        case .pi:        return profile.piScore
        case .math:      return profile.mathScore
        case .chemistry: return profile.chemScore
        case .geography: return profile.geoScore
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
        let base = social.globalLeaderboard
        return searchText.isEmpty
            ? base
            : base.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: MDSpacing.xs) {
                if selectedTab == 0 {
                    friendsSection
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
        }
    }

    @ViewBuilder
    private var rankedFriendsSection: some View {
        let ranked = buildRanked(social.friendsLeaderboard, own: ownEntry)
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
                Text("\(rank)")
                    .mdStyle(.bodyMd)
                    .foregroundStyle(rank == 1 && !isOwn ? Color.mdAmber : Color.mdText3)
                    .frame(width: 24, alignment: .center)

                MDAvatar(username: profile.username, size: .sm)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: MDSpacing.xxs) {
                        Text("\(profile.username)")
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdText)
                        if isOwn {
                            MDPillTag(label: String(localized: "your_label"), variant: .accent)
                        }
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

                Spacer()

                Text("\(score(for: profile, mode: scoreMode))p")
                    .mdStyle(.bodyMd)
                    .foregroundStyle(rank == 1 && !isOwn ? Color.mdAmber : Color.mdText2)
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

    private func rowBackground(rank: Int, isOwn: Bool) -> Color {
        if isOwn        { return .mdAccentSoft }
        if rank == 1    { return .mdAmberSoft }
        return .mdSurface2
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
            combined.append(own)
        }
        return combined
            .sorted { score(for: $0, mode: scoreMode) > score(for: $1, mode: scoreMode) }
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
            MDAvatar(username: profile.username, size: .sm)
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

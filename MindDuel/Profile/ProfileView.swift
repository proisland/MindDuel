import SwiftUI

struct ProfileView: View {
    let username: String
    let onSignOut: () -> Void
    @ObservedObject private var progression = ProgressionStore.shared
    @ObservedObject private var social = SocialStore.shared
    @ObservedObject private var avatar = AvatarStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showAvatarPicker = false
    @State private var selectedFriend: UserProfile? = nil
    @State private var showFlagExplanation = false

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "profile_title"), leadingAction: { dismiss() }) {
                    Button { showSettings = true } label: {
                        ZStack {
                            Circle().fill(Color.mdSurface2).frame(width: 28, height: 28)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.mdText2)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(spacing: MDSpacing.lg) {

                        // Avatar + identity
                        VStack(spacing: MDSpacing.xs) {
                            Button { showAvatarPicker = true } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    MDAvatar(username: username, size: .lg,
                                             customEmoji: avatar.emoji,
                                             customImageData: avatar.imageData)
                                    ZStack {
                                        Circle().fill(Color.mdAccent).frame(width: 22, height: 22)
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .offset(x: 2, y: 2)
                                }
                            }
                            .buttonStyle(.plain)
                            HStack(spacing: MDSpacing.xxs) {
                                Text("\(username)")
                                    .mdStyle(.title2)
                                    .foregroundStyle(Color.mdText)
                                if progression.isFlagged {
                                    Button { showFlagExplanation = true } label: {
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.mdRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if progression.isPremium {
                                    MDPillTag(label: String(localized: "premium_label"), variant: .amber)
                                }
                            }
                            Text(String(localized: "stats_member_since_april"))
                                .mdStyle(.caption)
                                .foregroundStyle(Color.mdText3)
                        }
                        .padding(.top, MDSpacing.lg)

                        // FREMGANG — same compact horizontal cards as the
                        // home screen's favorites grid for visual continuity.
                        let playedModes = GameMode.allCases.filter { progression.bestScore(for: $0) > 0 }
                        if !playedModes.isEmpty {
                            sectionContainer(String(localized: "progress_section_title")) {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                                    GridItem(.flexible(), spacing: 10)],
                                          spacing: 10) {
                                    ForEach(playedModes) { mode in
                                        MDFeaturedCard(
                                            mode: mode,
                                            score: progression.bestScore(for: mode),
                                            level: progression.level(for: mode)
                                        )
                                    }
                                }
                            }
                        }

                        // STATISTIKK
                        sectionContainer(String(localized: "stats_section_title")) {
                            VStack(spacing: 0) {
                                statRow(label: String(localized: "stats_rounds_played_label"),
                                        value: "\(progression.totalRoundsPlayed)")
                                Divider().background(Color.mdBorder2)
                                statRow(label: String(localized: "stats_friends_count_label"),
                                        value: "\(social.friends.count)")
                                Divider().background(Color.mdBorder2)
                                statRow(label: String(localized: "stats_avg_answer_time_label"),
                                        value: progression.totalCorrectAnswers > 0
                                            ? String(format: "%.1f s", progression.averageAnswerTime)
                                            : "–")
                                Divider().background(Color.mdBorder2)
                                statRow(label: String(localized: "stats_last_active_label"),
                                        value: timeAgoString(from: progression.lastActiveAt))
                            }
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
                        }

                        // VENNER
                        sectionContainer(String(localized: "friends_section_title")) {
                            friendsRow
                        }

                        Spacer(minLength: MDSpacing.xl)
                    }
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.bottom, MDSpacing.xl)
                }
            }

            if showFlagExplanation { flagModal }
        }
        .animation(.easeInOut(duration: 0.2), value: showFlagExplanation)
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(onSignOut: onSignOut)
        }
        .fullScreenCover(isPresented: $showAvatarPicker) {
            AvatarPickerSheet()
        }
        .fullScreenCover(item: $selectedFriend) { friend in
            OtherProfileView(profile: friend, ownUsername: username)
        }
    }

    // MARK: – Friends row

    private var friendsRow: some View {
        VStack(spacing: MDSpacing.sm) {
            // Pending requests with accept / decline
            ForEach(social.pendingRequests) { req in
                HStack(spacing: MDSpacing.sm) {
                    MDAvatar(username: req.username, size: .sm)
                    Text("\(req.username)")
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                    Spacer()
                    MDButton(.ghost, title: String(localized: "decline_action")) {
                        social.declineRequest(from: req.username)
                    }
                    .frame(width: 72)
                    MDButton(.primary, title: String(localized: "accept_action")) {
                        social.acceptRequest(from: req.username)
                    }
                    .frame(width: 72)
                }
                .padding(.horizontal, MDSpacing.md)
                .padding(.vertical, MDSpacing.sm)
                .background(Color.mdSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
            }

            // Accepted friends (horizontal scroll)
            if social.friends.isEmpty {
                if social.pendingRequests.isEmpty {
                    Text(String(localized: "no_friends_yet"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                        .padding(.vertical, MDSpacing.sm)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MDSpacing.sm) {
                        ForEach(social.friends) { friend in
                            Button { selectedFriend = friend } label: {
                                VStack(spacing: MDSpacing.xxs) {
                                    MDAvatar(username: friend.username, size: .sm)
                                    Text("\(friend.username)")
                                        .mdStyle(.micro)
                                        .foregroundStyle(Color.mdText3)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    social.removeFriend(username: friend.username)
                                } label: {
                                    Label(String(localized: "remove_friend_action"), systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: – Helpers

    private func sectionContainer<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            Text(title)
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
            content()
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .mdStyle(.caption)
                .foregroundStyle(Color.mdText2)
            Spacer()
            Text(value)
                .mdStyle(.caption)
                .foregroundStyle(Color.mdText)
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
    }

    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return String(localized: "time_just_now") }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)t" }
        return "\(hours / 24)d"
    }

    // MARK: – Flag modal

    private var flagModal: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { showFlagExplanation = false }
            VStack(spacing: MDSpacing.md) {
                ZStack {
                    Circle().fill(Color.mdRedSoft).frame(width: 56, height: 56)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.mdRed)
                }
                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "flagged_explanation_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "flagged_explanation_body"))
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                }
                MDButton(.ghost, title: String(localized: "continue_playing_action")) {
                    showFlagExplanation = false
                }
            }
            .padding(MDSpacing.lg)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mdBorder2, lineWidth: 0.5))
            .padding(.horizontal, MDSpacing.lg)
        }
    }
}

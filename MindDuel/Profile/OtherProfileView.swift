import SwiftUI

struct OtherProfileView: View {
    let profile: UserProfile
    let ownUsername: String
    @ObservedObject private var social = SocialStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showFlagExplanation = false
    @State private var showChallenge = false
    @State private var loadedProfile: PublicUserProfile? = nil

    private var isFriend: Bool { social.friendUsernames.contains(profile.username) }
    private var hasSentRequest: Bool { social.sentRequestUsernames.contains(profile.username) }

    private static let memberSinceFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: "", leadingAction: { dismiss() }) {
                    EmptyView()
                }

                ScrollView {
                    VStack(spacing: MDSpacing.lg) {
                        // Avatar block
                        VStack(spacing: MDSpacing.xs) {
                            MDAvatar(username: profile.username, size: .lg,
                                     customEmoji: profile.avatarEmoji == "🧠" ? nil : profile.avatarEmoji)
                            HStack(spacing: MDSpacing.xxs) {
                                Text("\(profile.username)")
                                    .mdStyle(.title2)
                                    .foregroundStyle(Color.mdText)
                                if profile.isFlagged {
                                    Button { showFlagExplanation = true } label: {
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.mdRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if profile.isPremium {
                                    MDPillTag(label: String(localized: "premium_label"), variant: .amber)
                                }
                            }
                            if let age = profile.age, let city = profile.city {
                                Text(String(format: String(localized: "other_profile_subtitle_format"), age, city))
                                    .mdStyle(.caption)
                                    .foregroundStyle(Color.mdText3)
                            }
                            HStack(spacing: MDSpacing.xxs) {
                                Text(String(localized: "stats_last_active_label") + ":")
                                    .mdStyle(.micro)
                                    .foregroundStyle(Color.mdText3)
                                Text(lastActiveDisplay)
                                    .mdStyle(.micro)
                                    .foregroundStyle(Color.mdGreen)
                            }
                        }
                        .padding(.top, MDSpacing.lg)

                        // Mode cards — same compact horizontal layout as the
                        // home screen's favorites grid.
                        let playedModes = GameMode.allCases.filter { profile.score(for: $0) > 0 }
                        if !playedModes.isEmpty {
                            sectionContainer(String(localized: "progress_section_title")) {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                                    GridItem(.flexible(), spacing: 10)],
                                          spacing: 10) {
                                    ForEach(playedModes) { mode in
                                        MDFeaturedCard(mode: mode,
                                                       score: profile.score(for: mode),
                                                       level: profile.level(for: mode))
                                    }
                                }
                            }
                        }

                        // Stats
                        sectionContainer(String(localized: "stats_section_title")) {
                            VStack(spacing: 0) {
                                statRow(label: String(localized: "stats_rounds_played_label"),
                                        value: "\(loadedProfile?.roundsPlayed ?? profile.roundsPlayed)")
                                Divider().background(Color.mdBorder2)
                                statRow(label: String(localized: "stats_avg_answer_time_label"),
                                        value: avgAnswerTimeDisplay)
                                Divider().background(Color.mdBorder2)
                                statRow(label: String(localized: "stats_member_since_label"),
                                        value: memberSinceDisplay)
                            }
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
                        }

                        // Action buttons
                        HStack(spacing: MDSpacing.sm) {
                            if isFriend {
                                MDButton(.primary, title: String(localized: "challenge_action")) {
                                    showChallenge = true
                                }
                                MDButton(.danger, title: String(localized: "remove_friend_action")) {
                                    social.removeFriend(username: profile.username)
                                    dismiss()
                                }
                            } else if hasSentRequest {
                                MDButton(.ghost, title: String(localized: "friend_request_sent_label")) { }
                                    .disabled(true)
                            } else {
                                MDButton(.primary, title: String(localized: "add_friend_action")) {
                                    social.sendFriendRequest(to: profile.username)
                                }
                            }
                        }
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.bottom, MDSpacing.xl)
                    }
                    .padding(.horizontal, MDSpacing.md)
                }
            }

            if showFlagExplanation {
                flagModal
            }
        }
        .onAppear { loadProfile() }
        .animation(.easeInOut(duration: 0.2), value: showFlagExplanation)
        .fullScreenCover(isPresented: $showChallenge) {
            MultiplayerLobbyView(ownUsername: ownUsername, startAsHost: true, invitedUsername: profile.username)
        }
    }

    // MARK: – Computed display values

    private var lastActiveDisplay: String {
        if let date = loadedProfile?.lastActiveAt {
            return UserProfile.relativeTime(date)
        }
        return profile.lastActive
    }

    private var avgAnswerTimeDisplay: String {
        if let lp = loadedProfile {
            return lp.avgAnswerTimeMs > 0
                ? String(format: "%.1f s", lp.avgAnswerTimeMs / 1000)
                : "–"
        }
        return profile.avgAnswerTime > 0
            ? String(format: "%.1f s", profile.avgAnswerTime)
            : "–"
    }

    private var memberSinceDisplay: String {
        if let date = loadedProfile?.memberSince {
            return Self.memberSinceFormatter.string(from: date)
        }
        return profile.memberSince
    }

    private func loadProfile() {
        Task {
            let result: PublicUserProfile? = try? await APIClient.shared.get("users/\(profile.username)")
            await MainActor.run { loadedProfile = result }
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

import SwiftUI

struct OtherProfileView: View {
    let profile: UserProfile
    let ownUsername: String
    @StateObject private var social = SocialStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showFlagExplanation = false
    @State private var showChallenge = false

    private var isFriend: Bool { social.friendUsernames.contains(profile.username) }
    private var hasSentRequest: Bool { social.sentRequestUsernames.contains(profile.username) }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: "@\(profile.username)", leadingAction: { dismiss() }) {
                    EmptyView()
                }

                ScrollView {
                    VStack(spacing: MDSpacing.lg) {
                        // Avatar block
                        VStack(spacing: MDSpacing.xs) {
                            MDAvatar(username: profile.username, size: .lg)
                            HStack(spacing: MDSpacing.xxs) {
                                Text("@\(profile.username)")
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
                                Text(profile.lastActive)
                                    .mdStyle(.micro)
                                    .foregroundStyle(Color.mdGreen)
                            }
                        }
                        .padding(.top, MDSpacing.lg)

                        // Mode cards
                        sectionContainer(String(localized: "progress_section_title")) {
                            HStack(spacing: MDSpacing.sm) {
                                MDModeCard(mode: .pi, score: profile.piScore, level: profile.piLevel, maxLevel: 20, compact: true) { }
                                    .disabled(true)
                                MDModeCard(mode: .math, score: profile.mathScore, level: profile.mathLevel, maxLevel: 20, compact: true) { }
                                    .disabled(true)
                            }
                        }

                        // Stats
                        sectionContainer(String(localized: "stats_section_title")) {
                            VStack(spacing: 0) {
                                statRow(label: String(localized: "stats_rounds_played_label"),
                                        value: "\(profile.roundsPlayed)")
                                Divider().background(Color.mdBorder2)
                                statRow(label: String(localized: "stats_member_since_label"),
                                        value: profile.memberSince)
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
        .animation(.easeInOut(duration: 0.2), value: showFlagExplanation)
        .fullScreenCover(isPresented: $showChallenge) {
            MultiplayerLobbyView(ownUsername: ownUsername, startAsHost: true, invitedUsername: profile.username)
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

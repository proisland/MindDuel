import SwiftUI

struct ActivityListView: View {
    let ownUsername: String

    @ObservedObject private var store  = MultiplayerStore.shared
    @ObservedObject private var social = SocialStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var kudosSent: Set<String> = []
    @State private var selectedUsername: String? = nil

    @State private var nowTick = Date()
    private let tickTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

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
        let gameRows   = store.recentActivity.map { FeedRow.game($0) }
        let socialRows = social.socialFeed.map { FeedRow.social($0) }
        return (gameRows + socialRows).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "recent_activity_all_title"), leadingAction: { dismiss() }) {
                    EmptyView()
                }

                let rows = mergedFeed
                if rows.isEmpty {
                    Spacer()
                    VStack(spacing: MDSpacing.sm) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.mdText3)
                        Text(String(localized: "no_activity_yet"))
                            .mdStyle(.body)
                            .foregroundStyle(Color.mdText3)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: MDSpacing.xs) {
                            ForEach(rows) { row in
                                switch row {
                                case .game(let item):   gameRow(item)
                                case .social(let item): socialRow(item)
                                }
                            }
                        }
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.vertical, MDSpacing.md)
                    }
                }
            }
        }
        .onReceive(tickTimer) { nowTick = $0 }
        .fullScreenCover(item: Binding(
            get: { selectedUsername.map { UserProfile.stub(username: $0) } },
            set: { selectedUsername = $0?.username }
        )) { profile in
            OtherProfileView(profile: profile, ownUsername: ownUsername)
        }
    }

    private func gameRow(_ item: MultiplayerActivityItem) -> some View {
        HStack(spacing: MDSpacing.sm) {
            Button { selectedUsername = item.opponentUsername } label: {
                ZStack(alignment: .bottomTrailing) {
                    MDAvatar(username: item.opponentUsername, size: .sm)
                    Circle()
                        .fill(item.didWin ? Color.mdGreen : Color.mdRed)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
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
                .id(nowTick)  // force re-render on tick
            if let roomId = item.roomId {
                let alreadySent = kudosSent.contains(roomId)
                Button {
                    kudosSent.insert(roomId)
                    Task { try? await ActivityService.sendKudos(roomId: roomId) }
                } label: {
                    Image(systemName: alreadySent ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 14))
                        .foregroundStyle(alreadySent ? Color.mdAccent : Color.mdText3)
                }
                .buttonStyle(.plain)
                .disabled(alreadySent)
            }
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    @ViewBuilder
    private func socialRow(_ item: SocialFeedItem) -> some View {
        HStack(spacing: MDSpacing.sm) {
            switch item.type {
            case .newFriend:
                let friendUsername = item.isMe == true
                    ? (item.user2?.username ?? "?")
                    : (item.user1?.username ?? "?")
                Button { selectedUsername = friendUsername } label: {
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
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    if item.isMe == true {
                        Text("Du og @\(item.user2?.username ?? "?") ble venner")
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdText)
                    } else {
                        Text("@\(item.user1?.username ?? "?") og @\(item.user2?.username ?? "?") ble venner")
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdText)
                    }
                }
            case .streak:
                let streakUser = item.user?.username ?? (item.isMine == true ? ownUsername : "")
                Button { if item.isMine != true, !streakUser.isEmpty { selectedUsername = streakUser } } label: {
                    ZStack(alignment: .bottomTrailing) {
                        MDAvatar(username: streakUser.isEmpty ? ownUsername : streakUser, size: .sm)
                        Text("🔥").font(.system(size: 11)).offset(x: 3, y: 3)
                    }
                }
                .buttonStyle(.plain)
                .disabled(item.isMine == true)
                VStack(alignment: .leading, spacing: 2) {
                    let who = item.isMine == true ? "Du" : "@\(streakUser)"
                    let modeStr = item.modeName.map { " i \($0)" } ?? ""
                    let streakText = "\(who) holder \(item.streakCount ?? 0)-dagers streak\(modeStr)"
                    Text(verbatim: streakText)
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .unknown:
                EmptyView()
            }
            Spacer()
            Text(UserProfile.relativeTime(item.createdAt))
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
                .id(nowTick)
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    private func modeLabel(for mode: GameMode) -> String {
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
}

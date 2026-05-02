import SwiftUI

struct ActiveGamesView: View {
    let ownUsername: String
    @ObservedObject private var store = MultiplayerStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showGame = false
    @State private var resumeSoloMode: GameMode? = nil
    @State private var resumeSoloRoomID: String? = nil

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "active_games_title"), leadingAction: { dismiss() }) {
                    EmptyView()
                }

                ScrollView {
                    LazyVStack(spacing: MDSpacing.xs) {
                        ForEach(store.playingRooms) { room in
                            roomRow(room)
                        }
                    }
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.vertical, MDSpacing.md)
                }
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            MultiplayerGameView(ownUsername: ownUsername)
        }
        .fullScreenCover(item: $resumeSoloMode) { mode in
            switch mode {
            case .pi:        PiGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .math:      MathGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .chemistry: ChemistryGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .geography: GeographyGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            }
        }
    }

    private func roomRow(_ room: MultiplayerRoom) -> some View {
        let modeColor: Color
        let modeBgSoft: Color
        switch room.mode {
        case .pi:        modeColor = .mdAccent; modeBgSoft = .mdAccentSoft
        case .math:      modeColor = .mdPink;   modeBgSoft = .mdPinkSoft
        case .chemistry: modeColor = .mdGreen;  modeBgSoft = .mdGreenSoft
        case .geography: modeColor = .mdAmber;  modeBgSoft = .mdAmberSoft
        }
        let isMyTurn = room.isMyTurn

        return HStack(spacing: MDSpacing.sm) {
            // Tappable main area: rejoin / resume
            Button {
                if room.isStandaloneSolo {
                    resumeSoloRoomID = room.id
                    resumeSoloMode = room.mode
                } else {
                    store.rejoin(roomID: room.id)
                    showGame = true
                }
            } label: {
                HStack(spacing: MDSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(modeBgSoft)
                            .frame(width: 40, height: 40)
                        ModeGlyph(mode: room.mode, size: 18, color: modeColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: String(localized: "multiplayer_room_code_format"), room.id))
                            .mdStyle(.bodyMd)
                            .foregroundStyle(Color.mdText)
                        if room.isStandaloneSolo {
                            Text(String(localized: "solo_session_subtitle"))
                                .mdStyle(.caption)
                                .foregroundStyle(Color.mdText3)
                        } else {
                            let opponents = room.players.filter { !$0.isYou }.map { "\($0.username)" }.joined(separator: ", ")
                            Text(opponents)
                                .mdStyle(.caption)
                                .foregroundStyle(Color.mdText3)
                        }
                        // #48 + #49: level + last-activity timestamp so players
                        // can decide whether to discard a stale session.
                        HStack(spacing: MDSpacing.xs) {
                            Text(String(format: String(localized: "active_games_level_format"),
                                        levelForRoom(room)))
                            Text("·")
                            Text(timeAgo(from: room.lastActivityAt))
                        }
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if isMyTurn {
                            Text(String(localized: "multiplayer_your_turn_label"))
                                .mdStyle(.micro)
                                .foregroundStyle(Color.mdGreen)
                        } else {
                            HStack(spacing: MDSpacing.xxs) {
                                Circle().fill(Color.mdGreen).frame(width: 6, height: 6)
                                Text(String(localized: "multiplayer_live_label"))
                                    .mdStyle(.micro)
                                    .foregroundStyle(Color.mdGreen)
                            }
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.mdText3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Visible leave/discard affordance (issue #23) — long-press menu
            // alone wasn't discoverable, so we expose a tappable trash icon.
            Button {
                store.leaveBackgroundRoom(id: room.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mdRed)
                    .frame(width: 36, height: 36)
                    .background(Color.mdRedSoft)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "discard_game_action"))
        }
        .padding(MDSpacing.md)
        .background(isMyTurn ? Color.mdGreen.opacity(0.06) : Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            isMyTurn ? Color.mdGreen.opacity(0.5) : Color.mdBorder2,
            lineWidth: isMyTurn ? 1 : 0.5))
    }

    private func levelForRoom(_ room: MultiplayerRoom) -> Int {
        switch room.mode {
        case .pi: return ProgressionStore.piLevel(forPosition: room.myPiDigitIndex)
        case .math, .chemistry, .geography: return max(1, room.startLevel)
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return String(localized: "time_just_now") }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)t" }
        return "\(hours / 24)d"
    }
}

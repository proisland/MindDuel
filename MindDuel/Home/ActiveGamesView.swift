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
                    let myTurn = store.playingRooms.filter { $0.isMyTurn }
                    let waiting = store.playingRooms.filter { !$0.isMyTurn }
                    LazyVStack(alignment: .leading, spacing: MDSpacing.sm) {
                        if !myTurn.isEmpty {
                            sectionHeader(String(format: String(localized: "active_games_my_turn_format"), myTurn.count))
                            ForEach(myTurn) { roomRow($0) }
                        }
                        if !waiting.isEmpty {
                            sectionHeader(String(format: String(localized: "active_games_waiting_format"), waiting.count))
                                .padding(.top, myTurn.isEmpty ? 0 : MDSpacing.sm)
                            ForEach(waiting) { roomRow($0) }
                        }
                        if store.playingRooms.isEmpty {
                            VStack(spacing: MDSpacing.sm) {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.mdText3)
                                Text(String(localized: "active_games_empty"))
                                    .mdStyle(.body)
                                    .foregroundStyle(Color.mdText3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, MDSpacing.xxl)
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
            case .pi:            PiGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .math:          MathGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .chemistry:     ChemistryGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .geography:     GeographyGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .brainTraining: BrainTrainingGameView(username: ownUsername)
            }
        }
    }

    private func roomRow(_ room: MultiplayerRoom) -> some View {
        let modeColor: Color
        let modeBgSoft: Color
        switch room.mode {
        case .pi:            modeColor = .mdAccent; modeBgSoft = .mdAccentSoft
        case .math:          modeColor = .mdPink;   modeBgSoft = .mdPinkSoft
        case .chemistry:     modeColor = .mdGreen;  modeBgSoft = .mdGreenSoft
        case .geography:     modeColor = .mdAmber;  modeBgSoft = .mdAmberSoft
        case .brainTraining: modeColor = .mdRed;    modeBgSoft = .mdRedSoft
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
                    // #84: tighter avatar-sized circle so rows look like the
                    // "All aktivitet" list. Information density unchanged.
                    ZStack {
                        Circle()
                            .fill(modeBgSoft)
                            .frame(width: 32, height: 32)
                        ModeGlyph(mode: room.mode, size: 15, color: modeColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if room.isStandaloneSolo {
                            Text(room.mode.localizedTitle)
                                .mdStyle(.bodyMd)
                                .foregroundStyle(Color.mdText)
                            Text(String(localized: "solo_session_subtitle"))
                                .mdStyle(.caption)
                                .foregroundStyle(Color.mdText3)
                        } else {
                            Text(roomDisplayName(room))
                                .mdStyle(.bodyMd)
                                .foregroundStyle(Color.mdText)
                            // #109: previously showed only opponent names. For
                            // host-created rooms with pending or dropped invitees
                            // that string was empty, leaving an information-less
                            // row. Now we always show participant count and a
                            // friendly fallback when there are no opponents yet.
                            Text(participantsLine(room))
                                .mdStyle(.caption)
                                .foregroundStyle(Color.mdText3)
                                .lineLimit(1)
                                .truncationMode(.tail)
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
        .padding(MDSpacing.sm)
        .background(isMyTurn ? Color.mdGreen.opacity(0.06) : Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            isMyTurn ? Color.mdGreen.opacity(0.5) : Color.mdBorder2,
            lineWidth: isMyTurn ? 1 : 0.5))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.mdText3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roomDisplayName(_ room: MultiplayerRoom) -> String {
        if !room.customName.isEmpty { return room.customName }
        return String(format: String(localized: "multiplayer_room_code_format"), room.id)
    }

    /// Build the per-row participants line. Includes invitees who were
    /// dropped at start (#109) so host-created rooms still show who was
    /// invited even if no one accepted.
    private func participantsLine(_ room: MultiplayerRoom) -> String {
        let inRoom = Set(room.players.map(\.username))
        let opponents = room.players.filter { !$0.isYou }.map(\.username)
        let droppedInvitees = room.invitedUsernames.filter { !inRoom.contains($0) }
        let totalCount = room.players.count + droppedInvitees.count
        let countLabel = String(format: String(localized: "active_games_player_count_format"),
                                totalCount)

        var names = opponents
        for name in droppedInvitees {
            names.append("\(name) " + String(localized: "active_games_pending_suffix"))
        }
        if names.isEmpty {
            return "\(countLabel) · \(String(localized: "active_games_waiting_for_players"))"
        }
        return "\(countLabel) · \(names.joined(separator: ", "))"
    }

    private func levelForRoom(_ room: MultiplayerRoom) -> Int {
        switch room.mode {
        case .pi: return ProgressionStore.piLevel(forPosition: room.myPiDigitIndex)
        case .math, .chemistry, .geography, .brainTraining: return max(1, room.startLevel)
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

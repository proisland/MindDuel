import SwiftUI

struct MultiplayerLobbyView: View {
    let ownUsername: String
    let startAsHost: Bool
    var invitedUsername: String? = nil

    @ObservedObject private var store     = MultiplayerStore.shared
    @ObservedObject private var social    = SocialStore.shared
    @ObservedObject private var progression = ProgressionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showGame        = false
    @State private var showFriendPicker = false

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        if let room = store.currentRoom {
                            modeSection(room: room, editable: isHost(room))
                            if isHost(room) && (room.mode == .math || room.mode == .chemistry) {
                                startLevelSection(room: room)
                            }
                            playersSection(room: room)
                            startButton(room: room)
                        }
                    }
                    .padding(.top, MDSpacing.lg)
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.bottom, MDSpacing.xl)
                }
            }
        }
        .onAppear {
            // For the invite-accept flow (#56) MultiplayerStore.acceptInvite
            // already seeded the room. Only fall back to seeding here if we
            // still have nothing — covers fresh "Create" and legacy "Join".
            if startAsHost {
                if store.currentRoom == nil {
                    store.createRoom(mode: .pi, ownUsername: ownUsername, invitedUsername: invitedUsername)
                }
            } else if store.currentRoom == nil {
                store.joinMockRoom(ownUsername: ownUsername)
            }
        }
        .onDisappear {
            if store.currentRoom?.status == .lobby {
                store.leaveRoom()
            }
        }
        .onChange(of: store.currentRoom?.status) { status in
            if status == .playing && !showGame { showGame = true }
        }
        .onChange(of: showGame) { isShowing in
            if !isShowing { dismiss() }
        }
        .sheet(isPresented: $showFriendPicker) {
            friendPickerSheet
        }
        .fullScreenCover(isPresented: $showGame) {
            MultiplayerGameView(ownUsername: ownUsername)
        }
    }

    private func isHost(_ room: MultiplayerRoom) -> Bool {
        room.players.first(where: { $0.isYou })?.isHost == true
    }

    // MARK: – Top bar

    private var topBar: some View {
        MDTopBar(title: String(localized: "multiplayer_lobby_title"), leadingAction: { dismiss() }) {
            if let room = store.currentRoom {
                Text(String(format: String(localized: "multiplayer_room_code_format"), room.id))
                    .mdStyle(.micro)
                    .lineLimit(1)
                    .foregroundStyle(Color.mdAccent)
                    .padding(.horizontal, MDSpacing.xs)
                    .padding(.vertical, 4)
                    .background(Color.mdAccentSoft)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: – Mode section

    @ViewBuilder
    private func modeSection(room: MultiplayerRoom, editable: Bool) -> some View {
        sectionLabel(String(localized: "multiplayer_mode_label"))
        HStack(spacing: MDSpacing.sm) {
            modeButton(.pi,        room: room, editable: editable)
            modeButton(.math,      room: room, editable: editable)
            modeButton(.chemistry, room: room, editable: editable)
        }
    }

    private func modeButton(_ mode: GameMode, room: MultiplayerRoom, editable: Bool) -> some View {
        let isActive = room.mode == mode
        let title: String
        let icon: String
        let color: Color
        switch mode {
        case .pi:        title = String(localized: "mode_pi");        icon = "π"; color = .mdAccent
        case .math:      title = String(localized: "mode_math");      icon = "∑"; color = .mdPink
        case .chemistry: title = String(localized: "mode_chemistry"); icon = "⚗︎"; color = .mdGreen
        }
        return Button {
            if editable { store.currentRoom?.mode = mode }
        } label: {
            HStack(spacing: MDSpacing.xs) {
                Text(icon).font(.system(size: 16, weight: .heavy)).foregroundStyle(isActive ? color : Color.mdText3)
                Text(title).mdStyle(.bodyMd).foregroundStyle(isActive ? Color.mdText : Color.mdText3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MDSpacing.sm)
            .background(isActive ? Color.mdSurface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? color : Color.mdBorder2, lineWidth: isActive ? 1 : 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!editable && !isActive)
    }

    // MARK: – Start level section

    private func startLevelSection(room: MultiplayerRoom) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            sectionLabel(String(localized: "multiplayer_start_level_label"))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(localized: "multiplayer_start_level_value"), room.startLevel))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                    // Curriculum label (issue #40) — same labelling as MathGameView
                    // so the host knows what school level the start level maps to.
                    Text(MathProblemGenerator.curriculumLabel(forLevel: room.startLevel))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
                HStack(spacing: MDSpacing.sm) {
                    Button {
                        if let lvl = store.currentRoom?.startLevel, lvl > 1 {
                            store.currentRoom?.startLevel = lvl - 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(room.startLevel > 1 ? Color.mdAccent : Color.mdText3)
                    }
                    .buttonStyle(.plain)
                    Text("\(room.startLevel)")
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdText)
                        .frame(width: 28, alignment: .center)
                    Button {
                        if let lvl = store.currentRoom?.startLevel, lvl < 20 {
                            store.currentRoom?.startLevel = lvl + 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(room.startLevel < 20 ? Color.mdAccent : Color.mdText3)
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
    }

    // MARK: – Players section

    private func playersSection(room: MultiplayerRoom) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            sectionLabel(String(format: String(localized: "multiplayer_players_label_format"),
                                room.players.count, 8))
            VStack(spacing: 0) {
                ForEach(room.players) { player in
                    playerRow(player)
                    Divider().background(Color.mdBorder2)
                }
                inviteRow
            }
            .background(Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        }
    }

    private func playerRow(_ player: MultiplayerPlayer) -> some View {
        let mode = store.currentRoom?.mode ?? .pi
        let level: Int
        let score: Int
        switch mode {
        case .pi:        level = player.piLevel;   score = player.piBestScore
        case .math:      level = player.mathLevel; score = player.mathBestScore
        case .chemistry: level = player.chemLevel; score = player.chemBestScore
        }
        return HStack(spacing: MDSpacing.sm) {
            MDAvatar(username: player.username, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MDSpacing.xxs) {
                    Text("\(player.username)").mdStyle(.caption).foregroundStyle(Color.mdText)
                    if player.isHost { MDPillTag(label: String(localized: "multiplayer_host_label"), variant: .accent) }
                    if player.isYou  { MDPillTag(label: String(localized: "your_label"), variant: .neutral) }
                }
                Text(String(format: String(localized: "multiplayer_player_stats_format"),
                            level, score))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdText3)
            }
            Spacer()
            if player.isReady {
                MDPillTag(label: String(localized: "multiplayer_ready_label"), variant: .green)
            } else {
                MDPillTag(label: String(localized: "multiplayer_waiting_label"), variant: .amber)
            }
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
    }

    private var inviteRow: some View {
        Button { showFriendPicker = true } label: {
            HStack(spacing: MDSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color.mdAccentSoft).frame(width: 24, height: 24)
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.mdAccent)
                }
                Text(String(localized: "multiplayer_invite_label"))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText3)
                Spacer()
            }
            .padding(.horizontal, MDSpacing.md)
            .padding(.vertical, MDSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Start / Ready button

    @ViewBuilder
    private func startButton(room: MultiplayerRoom) -> some View {
        if isHost(room) {
            MDButton(.primary, title: String(localized: "multiplayer_start_action")) {
                store.startGame()
                showGame = true
            }
            .disabled(!store.allReady || progression.isQuotaExhausted)
        } else {
            let youReady = room.players.first(where: { $0.isYou })?.isReady ?? false
            MDButton(youReady ? .ghost : .primary,
                     title: youReady
                        ? String(localized: "multiplayer_waiting_for_host_label")
                        : String(localized: "multiplayer_ready_action")) {
                if !progression.isQuotaExhausted { store.toggleReady() }
            }
            .disabled(youReady || progression.isQuotaExhausted)
        }
    }

    // MARK: – Friend picker sheet

    private var friendPickerSheet: some View {
        let inRoom = store.currentRoom?.players.map(\.username) ?? []
        let available = social.friends.filter { !inRoom.contains($0.username) }
        return NavigationView {
            ZStack {
                Color.mdBg.ignoresSafeArea()
                Group {
                    if available.isEmpty {
                        VStack(spacing: MDSpacing.sm) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.mdText3)
                            Text(String(localized: "no_friends_to_invite"))
                                .mdStyle(.body)
                                .foregroundStyle(Color.mdText3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(available) { friend in
                            Button {
                                store.inviteFriend(username: friend.username, playerID: friend.id)
                                showFriendPicker = false
                            } label: {
                                HStack(spacing: MDSpacing.sm) {
                                    MDAvatar(username: friend.username, size: .sm)
                                    Text("\(friend.username)")
                                        .mdStyle(.caption)
                                        .foregroundStyle(Color.mdText)
                                    Spacer()
                                    Image(systemName: "person.badge.plus")
                                        .foregroundStyle(Color.mdAccent)
                                }
                                .padding(.vertical, MDSpacing.xs)
                            }
                            .listRowBackground(Color.mdSurface2)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(String(localized: "multiplayer_invite_label"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "continue_action")) { showFriendPicker = false }
                        .foregroundStyle(Color.mdAccent)
                }
            }
        }
    }

    // MARK: – Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text).mdStyle(.micro).foregroundStyle(Color.mdText3)
    }
}

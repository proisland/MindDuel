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
    @State private var pickerSelection: Set<String> = []

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        if let room = store.currentRoom {
                            nameSection(room: room, editable: isHost(room))
                            modeSection(room: room, editable: isHost(room))
                            if isHost(room) && (room.mode == .math || room.mode == .chemistry || room.mode == .geography || room.mode == .brainTraining) {
                                startLevelSection(room: room)
                            }
                            if isHost(room) {
                                questionsPerTurnSection(room: room)
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

    /// Disable Start while the host is the only one in the room — they can't
    /// duel themselves. As soon as one invitee shows up the button enables,
    /// even if they haven't accepted yet (#81).
    private func hasOnlyHost(_ room: MultiplayerRoom) -> Bool {
        room.players.count <= 1
    }

    // MARK: – Top bar

    private var topBar: some View {
        MDTopBar(title: String(localized: "multiplayer_lobby_title"), leadingAction: { dismiss() }) {
            if let room = store.currentRoom {
                Text(room.customName.isEmpty
                     ? String(format: String(localized: "multiplayer_room_code_format"), room.id)
                     : room.customName)
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

    // MARK: – Name section (#83)

    @ViewBuilder
    private func nameSection(room: MultiplayerRoom, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            sectionLabel(String(localized: "multiplayer_name_label"))
            if editable {
                TextField(
                    String(localized: "multiplayer_name_placeholder"),
                    text: Binding(
                        get: { store.currentRoom?.customName ?? "" },
                        set: { store.currentRoom?.customName = $0 }
                    )
                )
                .mdStyle(.bodyMd)
                .foregroundStyle(Color.mdText)
                .padding(.horizontal, MDSpacing.md)
                .padding(.vertical, MDSpacing.sm)
                .background(Color.mdSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
            } else {
                Text(room.customName.isEmpty
                     ? String(format: String(localized: "multiplayer_room_code_format"), room.id)
                     : room.customName)
                    .mdStyle(.bodyMd)
                    .foregroundStyle(Color.mdText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.vertical, MDSpacing.sm)
                    .background(Color.mdSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
            }
        }
    }

    @ViewBuilder
    private func modeSection(room: MultiplayerRoom, editable: Bool) -> some View {
        sectionLabel(String(localized: "multiplayer_mode_label"))
        // Horizontally scrollable pills, mirroring the Home screen's
        // "Hurtig tilgang" layout so the host can pick from every mode
        // without crowding the lobby (per Claude Design iteration).
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameMode.allCases) { mode in
                    modeButton(mode, room: room, editable: editable)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func modeButton(_ mode: GameMode, room: MultiplayerRoom, editable: Bool) -> some View {
        let isActive = room.mode == mode
        let color = mode.accentColor
        return Button {
            if editable { store.currentRoom?.mode = mode }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(isActive ? 0.15 : 0.09))
                    ModeGlyph(mode: mode, size: 16, color: color)
                }
                .frame(width: 34, height: 34)
                Text(mode.localizedTitle)
                    .font(.system(size: 10, weight: isActive ? .heavy : .medium))
                    .foregroundStyle(isActive ? Color.mdText : Color.mdText3)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 66)
            .background(isActive ? mode.deepBg : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? color.opacity(0.7) : Color.white.opacity(0.08),
                                lineWidth: isActive ? 1.5 : 1))
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

    // MARK: – Questions per turn (#95)

    private func questionsPerTurnSection(room: MultiplayerRoom) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            sectionLabel(String(localized: "multiplayer_questions_per_turn_label"))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(localized: "multiplayer_questions_per_turn_value"),
                                room.questionsPerTurn))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "multiplayer_questions_per_turn_hint"))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
                HStack(spacing: MDSpacing.sm) {
                    Button {
                        if let q = store.currentRoom?.questionsPerTurn, q > 1 {
                            store.currentRoom?.questionsPerTurn = q - 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(room.questionsPerTurn > 1 ? Color.mdAccent : Color.mdText3)
                    }
                    .buttonStyle(.plain)
                    Text("\(room.questionsPerTurn)")
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdText)
                        .frame(width: 28, alignment: .center)
                    Button {
                        if let q = store.currentRoom?.questionsPerTurn, q < 10 {
                            store.currentRoom?.questionsPerTurn = q + 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(room.questionsPerTurn < 10 ? Color.mdAccent : Color.mdText3)
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
        case .pi:            level = player.piLevel;    score = player.piBestScore
        case .math:          level = player.mathLevel;  score = player.mathBestScore
        case .chemistry:     level = player.chemLevel;  score = player.chemBestScore
        case .geography:     level = player.geoLevel;   score = player.geoBestScore
        case .brainTraining: level = player.brainLevel; score = player.brainBestScore
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
            // #81: Host can press Start without waiting for all invitees to
            // accept. Pending invitees are dropped from the room on start
            // (handled in MultiplayerStore.startGame) so the game proceeds
            // with whoever responded.
            MDButton(.primary, title: String(localized: "multiplayer_start_action")) {
                store.startGame()
                showGame = true
            }
            .disabled(progression.isQuotaExhausted || hasOnlyHost(room))
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

    // MARK: – Friend picker sheet (#79, #80)
    //
    // Multi-select: the row trailing affordance is a checkmark, and the
    // host commits the whole batch with "Continue" at the bottom. Each row
    // also shows the friend's level for the chosen mode and a "last active"
    // timestamp so the host can pick active opponents.

    private var friendPickerSheet: some View {
        let inRoom = store.currentRoom?.players.map(\.username) ?? []
        let available = social.friends.filter { !inRoom.contains($0.username) }
        let mode = store.currentRoom?.mode ?? .pi
        return ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "multiplayer_invite_label"),
                         leadingAction: { closeFriendPicker() }) { EmptyView() }

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
                    ScrollView {
                        LazyVStack(spacing: MDSpacing.xs) {
                            ForEach(available) { friend in
                                pickerRow(friend: friend, mode: mode)
                            }
                        }
                        .padding(MDSpacing.md)
                    }

                    HStack(spacing: MDSpacing.sm) {
                        MDButton(.primary,
                                 title: String(format: String(localized: "multiplayer_invite_continue_format"),
                                               pickerSelection.count)) {
                            commitFriendPickerSelection(from: available)
                        }
                        .disabled(pickerSelection.isEmpty)
                        Spacer()
                        // #18: share sheet to invite people who aren't on
                        // MindDuel yet — they get a link to the App Store
                        // (placeholder until App Store listing is live) along
                        // with the room code so they can join after install.
                        ShareLink(item: shareInviteText, subject: Text(String(localized: "multiplayer_share_invite_subject"))) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.mdAccent)
                                .frame(width: 44, height: 44)
                                .background(Color.mdAccentSoft)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.mdAccent.opacity(0.5), lineWidth: 0.5))
                        }
                        Button { closeFriendPicker() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.mdText2)
                                .frame(width: 44, height: 44)
                                .background(Color.mdSurface2)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.mdBorder2, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.bottom, MDSpacing.lg)
                }
            }
        }
    }

    private func pickerRow(friend: UserProfile, mode: GameMode) -> some View {
        let isSelected = pickerSelection.contains(friend.username)
        let level = friend.level(for: mode)
        return Button {
            if isSelected { pickerSelection.remove(friend.username) }
            else          { pickerSelection.insert(friend.username) }
        } label: {
            HStack(spacing: MDSpacing.sm) {
                MDAvatar(username: friend.username, size: .sm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(friend.username)")
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "multiplayer_invite_level_format"),
                                    mode.localizedTitle, level))
                            .mdStyle(.micro)
                            .foregroundStyle(Color.mdText3)
                        Text("·").mdStyle(.micro).foregroundStyle(Color.mdText3)
                        Text(String(format: String(localized: "stats_last_active_inline"),
                                    friend.lastActive))
                            .mdStyle(.micro)
                            .foregroundStyle(Color.mdText3)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.mdAccent : Color.mdBorder2,
                                lineWidth: isSelected ? 2 : 1)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.mdAccent).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(MDSpacing.sm)
            .background(Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                isSelected ? Color.mdAccent.opacity(0.5) : Color.mdBorder2,
                lineWidth: isSelected ? 1 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func commitFriendPickerSelection(from friends: [UserProfile]) {
        for friend in friends where pickerSelection.contains(friend.username) {
            store.inviteFriend(username: friend.username, playerID: friend.id)
        }
        closeFriendPicker()
    }

    private func closeFriendPicker() {
        pickerSelection.removeAll()
        showFriendPicker = false
    }

    // MARK: – Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text).mdStyle(.micro).foregroundStyle(Color.mdText3)
    }

    /// #18: text shared via the system share sheet so non-users can join.
    /// Includes the room code so they can punch it in after installing.
    private var shareInviteText: String {
        let code = store.currentRoom?.id ?? ""
        return String(format: String(localized: "multiplayer_share_invite_body"), code)
    }
}

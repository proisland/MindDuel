import SwiftUI

struct MultiplayerLobbyView: View {
    let ownUsername: String
    let startAsHost: Bool
    var invitedUsername: String? = nil

    @StateObject private var store = MultiplayerStore.shared
    @StateObject private var progression = ProgressionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: GameMode = .pi
    @State private var showGame = false

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        if let room = store.currentRoom {
                            modeSection(room: room)
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
            if startAsHost {
                store.createRoom(mode: selectedMode, ownUsername: ownUsername, invitedUsername: invitedUsername)
            } else {
                store.joinMockRoom(ownUsername: ownUsername)
            }
        }
        .onDisappear {
            if store.currentRoom?.status == .lobby {
                store.leaveRoom()
            }
        }
        .onChange(of: store.currentRoom?.status) { status in
            if status == .playing && !showGame {
                showGame = true
            }
        }
        .onChange(of: showGame) { isShowing in
            if !isShowing {
                if store.currentRoom?.status != .playing {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            MultiplayerGameView(ownUsername: ownUsername)
        }
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

    // MARK: – Mode section (host only)

    @ViewBuilder
    private func modeSection(room: MultiplayerRoom) -> some View {
        let isHost = room.players.first(where: { $0.isYou })?.isHost == true
        if isHost {
            sectionLabel(String(localized: "multiplayer_mode_label"))
            HStack(spacing: MDSpacing.sm) {
                modeButton(.pi,   room: room)
                modeButton(.math, room: room)
            }
        }
    }

    private func modeButton(_ mode: GameMode, room: MultiplayerRoom) -> some View {
        let isActive = room.mode == mode
        let title = mode == .pi
            ? String(localized: "mode_pi")
            : String(localized: "mode_math")
        let icon  = mode == .pi ? "π" : "∑"
        let color: Color = mode == .pi ? .mdAccent : .mdPink

        return Button {
            store.currentRoom?.mode = mode
        } label: {
            HStack(spacing: MDSpacing.xs) {
                Text(icon)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(isActive ? color : Color.mdText3)
                Text(title)
                    .mdStyle(.bodyMd)
                    .foregroundStyle(isActive ? Color.mdText : Color.mdText3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MDSpacing.sm)
            .background(isActive ? Color.mdSurface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? color : Color.mdBorder2, lineWidth: isActive ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: – Players section

    private func playersSection(room: MultiplayerRoom) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            sectionLabel(String(format: String(localized: "multiplayer_players_label_format"),
                                room.players.count, 8))
            VStack(spacing: 0) {
                ForEach(room.players) { player in
                    playerRow(player, isLast: player.id == room.players.last?.id)
                }
                inviteRow(room: room)
            }
            .background(Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        }
    }

    private func playerRow(_ player: MultiplayerPlayer, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: MDSpacing.sm) {
                MDAvatar(username: player.username, size: .sm)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: MDSpacing.xxs) {
                        Text("@\(player.username)")
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdText)
                        if player.isHost {
                            MDPillTag(label: String(localized: "multiplayer_host_label"), variant: .accent)
                        }
                        if player.isYou {
                            MDPillTag(label: String(localized: "your_label"), variant: .neutral)
                        }
                    }
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

            if !isLast {
                Divider().background(Color.mdBorder2)
            }
        }
    }

    private func inviteRow(room: MultiplayerRoom) -> some View {
        let shareText = String(format: String(localized: "multiplayer_invite_share_format"), room.id)
        return VStack(spacing: 0) {
            Divider().background(Color.mdBorder2)
            ShareLink(item: shareText) {
                HStack(spacing: MDSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(Color.mdAccentSoft).frame(width: 24, height: 24)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.mdAccent)
                    }
                    Text(String(localized: "multiplayer_invite_label"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.mdText3)
                }
                .padding(.horizontal, MDSpacing.md)
                .padding(.vertical, MDSpacing.sm)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: – Start / Ready button

    @ViewBuilder
    private func startButton(room: MultiplayerRoom) -> some View {
        let isHost = room.players.first(where: { $0.isYou })?.isHost == true
        if isHost {
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
                if !progression.isQuotaExhausted {
                    store.toggleReady()
                }
            }
            .disabled(youReady || progression.isQuotaExhausted)
        }
    }

    // MARK: – Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .mdStyle(.micro)
            .foregroundStyle(Color.mdText3)
    }
}

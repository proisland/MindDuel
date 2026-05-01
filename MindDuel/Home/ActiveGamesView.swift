import SwiftUI

struct ActiveGamesView: View {
    let ownUsername: String
    @StateObject private var store = MultiplayerStore.shared
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
            case .pi:   PiGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            case .math: MathGameView(username: ownUsername, resumeRoomID: resumeSoloRoomID)
            }
        }
    }

    private func roomRow(_ room: MultiplayerRoom) -> some View {
        let modeColor: Color = room.mode == .pi ? .mdAccent : .mdPink
        let modeIcon = room.mode == .pi ? "π" : "∑"
        let modeName = room.mode == .pi
            ? String(localized: "mode_pi")
            : String(localized: "mode_math")
        let isMyTurn = room.isMyTurn

        return Button {
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
                        .fill(room.mode == .pi ? Color.mdAccentSoft : Color.mdPinkSoft)
                        .frame(width: 40, height: 40)
                    Text(modeIcon)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(modeColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: MDSpacing.xs) {
                        Text(String(format: String(localized: "multiplayer_room_code_format"), room.id))
                            .mdStyle(.bodyMd)
                            .foregroundStyle(Color.mdText)
                        Text(modeName)
                            .mdStyle(.micro)
                            .foregroundStyle(modeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(room.mode == .pi ? Color.mdAccentSoft : Color.mdPinkSoft)
                            .clipShape(Capsule())
                    }
                    let opponents = room.players.filter { !$0.isYou }.map { "@\($0.username)" }.joined(separator: ", ")
                    Text(opponents)
                        .mdStyle(.caption)
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
            .padding(MDSpacing.md)
            .background(isMyTurn ? Color.mdGreen.opacity(0.06) : Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                isMyTurn ? Color.mdGreen.opacity(0.5) : Color.mdBorder2,
                lineWidth: isMyTurn ? 1 : 0.5))
        }
        .buttonStyle(.plain)
    }
}

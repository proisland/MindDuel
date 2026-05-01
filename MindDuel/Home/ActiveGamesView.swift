import SwiftUI

struct ActiveGamesView: View {
    let ownUsername: String
    @StateObject private var store = MultiplayerStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showGame = false

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
    }

    private func roomRow(_ room: MultiplayerRoom) -> some View {
        Button {
            store.rejoin(roomID: room.id)
            showGame = true
        } label: {
            HStack(spacing: MDSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.mdPinkSoft).frame(width: 40, height: 40)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.mdPink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(localized: "multiplayer_room_code_format"), room.id))
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdText)
                    let opponents = room.players.filter { !$0.isYou }.map { "@\($0.username)" }.joined(separator: ", ")
                    Text(opponents)
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
                HStack(spacing: MDSpacing.xxs) {
                    Circle().fill(Color.mdGreen).frame(width: 6, height: 6)
                    Text(String(localized: "multiplayer_live_label"))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdGreen)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mdText3)
            }
            .padding(MDSpacing.md)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

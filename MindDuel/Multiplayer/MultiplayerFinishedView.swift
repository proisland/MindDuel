import SwiftUI

/// End-of-round screen shown when a multiplayer (or solo-of-multiplayer) game finishes.
/// Pulled out of MultiplayerGameView to keep that file under control; this subview is
/// pure presentation and just needs the room data + a couple of callbacks.
struct MultiplayerFinishedView: View {
    let room: MultiplayerRoom
    let onShowBreakdown: (MultiplayerPlayer) -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: MDSpacing.lg) {
                Spacer()

                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mdAmber)

                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "round_over_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText2)
                    if let winner = room.winner {
                        Text(winner.isYou
                             ? String(localized: "multiplayer_you_won_label")
                             : String(format: String(localized: "multiplayer_winner_format"),
                                      winner.username))
                            .mdStyle(.title)
                            .foregroundStyle(winner.isYou ? Color.mdAccent : Color.mdText)
                    }
                }

                leaderboard
                    .padding(.horizontal, MDSpacing.md)

                Spacer()

                MDButton(.primary, title: String(localized: "back_to_home_action"), action: onLeave)
                    .padding(.horizontal, MDSpacing.lg)
                    .padding(.bottom, MDSpacing.xl)
            }
        }
    }

    private var leaderboard: some View {
        let sorted = room.players.sorted { $0.score > $1.score }
        return VStack(spacing: MDSpacing.xs) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { rank, player in
                row(rank: rank, player: player)
            }
        }
    }

    private func row(rank: Int, player: MultiplayerPlayer) -> some View {
        HStack(spacing: MDSpacing.sm) {
            Text("\(rank + 1)")
                .mdStyle(.bodyMd)
                .foregroundStyle(rank == 0 ? Color.mdAmber : Color.mdText3)
                .frame(width: 20, alignment: .center)
            MDAvatar(username: player.username, size: .sm)
            Text("@\(player.username)")
                .mdStyle(.caption)
                .foregroundStyle(Color.mdText)
            if player.isYou {
                MDPillTag(label: String(localized: "your_label"), variant: .accent)
            }
            Spacer()
            Text("\(player.score)p")
                .mdStyle(.bodyMd)
                .foregroundStyle(rank == 0 ? Color.mdAmber : Color.mdText2)
            Button {
                onShowBreakdown(player)
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mdText3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
        .background(player.isYou ? Color.mdAccentSoft : (rank == 0 ? Color.mdAmberSoft : Color.mdSurface2))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }
}

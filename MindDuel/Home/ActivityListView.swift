import SwiftUI

struct ActivityListView: View {
    @ObservedObject private var store = MultiplayerStore.shared
    @Environment(\.dismiss) private var dismiss

    // Tick every 30s so timestamps like "1m" / "2t" refresh without the user
    // having to navigate away and back.
    @State private var nowTick = Date()
    private let tickTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "recent_activity_all_title"), leadingAction: { dismiss() }) {
                    EmptyView()
                }

                if store.recentActivity.isEmpty {
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
                            ForEach(store.recentActivity) { item in
                                activityRow(item)
                            }
                        }
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.vertical, MDSpacing.md)
                    }
                }
            }
        }
        .onReceive(tickTimer) { nowTick = $0 }
    }

    private func activityRow(_ item: MultiplayerActivityItem) -> some View {
        HStack(spacing: MDSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                MDAvatar(username: item.opponentUsername, size: .sm)
                Circle()
                    .fill(item.didWin ? Color.mdGreen : Color.mdRed)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: 2)
            }
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
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    private func modeLabel(for mode: GameMode) -> String {
        switch mode {
        case .pi:        return String(localized: "mode_pi")
        case .math:      return String(localized: "mode_math")
        case .chemistry: return String(localized: "mode_chemistry")
        }
    }
}

import SwiftUI

/// Lists pending multiplayer invites (#56). Replaces the old "Bli med" path
/// that dropped the user straight into a single mock room — now they can
/// pick which invite to accept (or decline).
struct MultiplayerInvitesView: View {
    let ownUsername: String
    let onAccept: () -> Void

    @ObservedObject private var store = MultiplayerStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "multiplayer_invites_title"),
                         leadingAction: { dismiss() }) { EmptyView() }

                if store.pendingInvites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: MDSpacing.xs) {
                            ForEach(store.pendingInvites) { invite in
                                inviteRow(invite)
                            }
                        }
                        .padding(MDSpacing.md)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: MDSpacing.sm) {
            Image(systemName: "envelope.open")
                .font(.system(size: 32))
                .foregroundStyle(Color.mdText3)
            Text(String(localized: "multiplayer_no_invites"))
                .mdStyle(.body)
                .foregroundStyle(Color.mdText3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inviteRow(_ invite: MultiplayerInvite) -> some View {
        let modeColor: Color
        let modeIcon: String
        let modeName: String
        switch invite.mode {
        case .pi:        modeColor = .mdAccent; modeIcon = "π";  modeName = String(localized: "mode_pi")
        case .math:      modeColor = .mdPink;   modeIcon = "∑";  modeName = String(localized: "mode_math")
        case .chemistry: modeColor = .mdGreen;  modeIcon = "⚗︎"; modeName = String(localized: "mode_chemistry")
        case .geography: modeColor = .mdAmber;  modeIcon = "🌍"; modeName = String(localized: "mode_geography")
        }
        return HStack(spacing: MDSpacing.sm) {
            ZStack {
                Circle().fill(modeColor.opacity(0.2)).frame(width: 36, height: 36)
                Text(modeIcon)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(modeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "multiplayer_invite_from_format"),
                            invite.hostUsername))
                    .mdStyle(.bodyMd)
                    .foregroundStyle(Color.mdText)
                HStack(spacing: MDSpacing.xs) {
                    Text(modeName)
                        .mdStyle(.micro)
                        .foregroundStyle(modeColor)
                    Text("·").mdStyle(.micro).foregroundStyle(Color.mdText3)
                    Text(timeAgo(from: invite.invitedAt))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                }
            }
            Spacer()
            Button {
                store.declineInvite(invite)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mdText3)
                    .frame(width: 32, height: 32)
                    .background(Color.mdSurface2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Button {
                store.acceptInvite(invite, ownUsername: ownUsername)
                onAccept()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.mdAccent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(MDSpacing.md)
        .background(Color.mdSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
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

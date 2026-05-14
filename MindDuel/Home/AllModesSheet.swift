import SwiftUI

/// "Alle spillmoduser" sheet shown from the home screen's favorites section.
/// Lists every mode with star-toggle for favorites and drag-handle reorder
/// that propagates back to ModePreferences (used by the favorites grid and
/// quick-access row on the home screen).
struct AllModesSheet: View {
    @ObservedObject private var prefs      = ModePreferences.shared
    @ObservedObject private var progression = ProgressionStore.shared
    @ObservedObject private var modeCache  = ModeConfigCache.shared
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    var onPlay: (GameMode) -> Void
    var onPlayServerMode: ((ServerMode) -> Void)?
    var onPractice: ((GameMode) -> Void)?

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "all_modes_title"),
                         leadingAction: { dismiss() }) { EmptyView() }

                searchBar
                    .padding(.horizontal, MDSpacing.md)
                    .padding(.top, MDSpacing.xs)

                HStack {
                    Text("\(displayedCombined.count) " + String(localized: "all_modes_count_suffix"))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.mdText3)
                    Spacer()
                    if search.isEmpty {
                        Text(String(localized: "all_modes_drag_hint"))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.mdText3.opacity(0.7))
                    }
                }
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.xs)
                .padding(.bottom, MDSpacing.xs)

                List {
                    ForEach(displayedCombined) { mode in
                        anyModeRow(mode)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: MDSpacing.md, bottom: 4, trailing: MDSpacing.md))
                    }
                    .onMove { source, destination in
                        guard search.isEmpty else { return }
                        prefs.moveCombined(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.mdBg)
                .environment(\.editMode, .constant(.active))
            }
        }
    }

    private var displayedCombined: [AnyMode] {
        guard !search.isEmpty else { return prefs.activeCombinedOrder }
        let q = search.lowercased()
        return prefs.activeCombinedOrder.filter { mode in
            switch mode {
            case .known(let gm):  return gm.localizedTitle.lowercased().contains(q)
            case .server(let sm): return sm.name.lowercased().contains(q)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: MDSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color.mdText3)
            TextField(String(localized: "all_modes_search_placeholder"), text: $search)
                .font(.system(size: 13))
                .foregroundStyle(Color.mdText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mdText3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MDSpacing.sm)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func anyModeRow(_ mode: AnyMode) -> some View {
        switch mode {
        case .known(let gm):  knownModeRow(gm)
        case .server(let sm): serverModeRow(sm)
        }
    }

    private func knownModeRow(_ mode: GameMode) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(mode.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(mode.accentColor.opacity(0.21), lineWidth: 1.5))
                ModeGlyph(mode: mode, size: 15, color: mode.accentColor)
            }
            .frame(width: 36, height: 36)
            .onTapGesture { onPlay(mode); dismiss() }
            .contextMenu {
                Button { onPlay(mode); dismiss() } label: {
                    Label(String(localized: "play_normal_action"), systemImage: "play.fill")
                }
                if (mode == .pi || mode == .math), let onPractice {
                    Button { onPractice(mode); dismiss() } label: {
                        Label(String(localized: "practice_round_action"), systemImage: "dumbbell.fill")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.localizedTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mdText)
                Text(String(format: String(localized: "level_of_format"),
                            progression.level(for: mode), 20))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mdText3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onPlay(mode); dismiss() }

            Text(formatPoints(progression.bestScore(for: mode)))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(mode.accentColor)

            let isFav = prefs.isFavorite(mode)
            let canStar = isFav || !prefs.isAtFavoriteCap
            Button {
                prefs.toggleFavorite(mode)
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(isFav
                                     ? Color.mdAmber
                                     : Color.mdText3.opacity(canStar ? 0.4 : 0.18))
            }
            .buttonStyle(.plain)
            .disabled(!canStar)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func serverModeRow(_ serverMode: ServerMode) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(serverMode.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(serverMode.accentColor.opacity(0.21), lineWidth: 1.5))
                ServerModeGlyph(iconSymbol: serverMode.iconSymbol, size: 15,
                                color: serverMode.accentColor)
            }
            .frame(width: 36, height: 36)
            .onTapGesture { onPlayServerMode?(serverMode); dismiss() }

            VStack(alignment: .leading, spacing: 1) {
                Text(serverMode.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mdText)
                Text(String(format: String(localized: "level_of_format"),
                            progression.level(forSlug: serverMode.slug), 20))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mdText3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onPlayServerMode?(serverMode); dismiss() }

            Text(formatPoints(progression.bestScore(forSlug: serverMode.slug)))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(serverMode.accentColor)

            let isFav = prefs.isFavoriteServer(slug: serverMode.slug)
            let canStar = isFav || !prefs.isAtFavoriteCap
            Button {
                prefs.toggleFavoriteServer(slug: serverMode.slug)
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(isFav
                                     ? Color.mdAmber
                                     : Color.mdText3.opacity(canStar ? 0.4 : 0.18))
            }
            .buttonStyle(.plain)
            .disabled(!canStar)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

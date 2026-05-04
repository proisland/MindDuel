import SwiftUI

/// "Alle spillmoduser" sheet shown from the home screen's favorites section.
/// Lists every mode with star-toggle for favorites and drag-handle reorder
/// that propagates back to ModePreferences (used by the favorites grid and
/// quick-access row on the home screen).
struct AllModesSheet: View {
    @ObservedObject private var prefs = ModePreferences.shared
    @ObservedObject private var progression = ProgressionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    var onPlay: (GameMode) -> Void

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
                    Text("\(displayed.count) " + String(localized: "all_modes_count_suffix"))
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
                    ForEach(displayed, id: \.self) { mode in
                        modeRow(mode)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: MDSpacing.md, bottom: 4, trailing: MDSpacing.md))
                    }
                    .onMove { source, destination in
                        guard search.isEmpty, let from = source.first else { return }
                        prefs.move(from: from, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.mdBg)
                .environment(\.editMode, .constant(.active))
            }
        }
    }

    private var displayed: [GameMode] {
        guard !search.isEmpty else { return prefs.order }
        let q = search.lowercased()
        return prefs.order.filter { $0.localizedTitle.lowercased().contains(q) }
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

    private func modeRow(_ mode: GameMode) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(mode.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(mode.accentColor.opacity(0.21), lineWidth: 1.5))
                ModeGlyph(mode: mode, size: 15, color: mode.accentColor)
            }
            .frame(width: 36, height: 36)
            .onTapGesture { onPlay(mode); dismiss() }

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

            Button {
                prefs.toggleFavorite(mode)
            } label: {
                Image(systemName: prefs.isFavorite(mode) ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(prefs.isFavorite(mode) ? Color.mdAmber : Color.mdText3.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

import SwiftUI

/// Half-sheet for choosing difficulty before starting a new game round.
struct DifficultyPickerSheet: View {
    @Binding var difficulty: String
    var onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: MDSpacing.lg) {
                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "difficulty_picker_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "difficulty_picker_subtitle"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
                .padding(.top, MDSpacing.lg)

                VStack(spacing: MDSpacing.sm) {
                    ForEach(GameDifficulty.allCases, id: \.rawValue) { level in
                        difficultyRow(level)
                    }
                }
                .padding(.horizontal, MDSpacing.md)

                Spacer()

                MDButton(.primary, title: String(localized: "difficulty_picker_start_action")) {
                    dismiss()
                    onStart()
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func difficultyRow(_ level: GameDifficulty) -> some View {
        let isSelected = difficulty == level.rawValue
        return Button {
            difficulty = level.rawValue
        } label: {
            HStack(spacing: MDSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.localizedTitle)
                        .mdStyle(.bodyMd)
                        .foregroundStyle(Color.mdText)
                    Text(level.localizedSubtitle)
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.mdAccent)
                }
            }
            .padding(MDSpacing.md)
            .background(isSelected ? Color.mdAccentSoft : Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.mdAccent : Color.mdBorder2, lineWidth: isSelected ? 1 : 0.5))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

extension GameDifficulty {
    var localizedTitle: String {
        switch self {
        case .easy:   return String(localized: "difficulty_easy")
        case .normal: return String(localized: "difficulty_normal")
        case .hard:   return String(localized: "difficulty_hard")
        }
    }

    var localizedSubtitle: String {
        switch self {
        case .easy:   return String(format: String(localized: "difficulty_seconds_format"), Int(timerSeconds))
        case .normal: return String(format: String(localized: "difficulty_seconds_format"), Int(timerSeconds))
        case .hard:   return String(format: String(localized: "difficulty_seconds_format"), Int(timerSeconds))
        }
    }
}

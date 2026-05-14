import SwiftUI

/// Half-sheet for choosing a start level (Math) or start digit (Pi) before a practice round.
struct PracticeSetupSheet: View {
    let mode: GameMode
    var onStart: (Int) -> Void

    @ObservedObject private var progression = ProgressionStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedValue: Int = 1

    private var maxValue: Int {
        switch mode {
        case .pi:   return max(1, progression.piPosition)
        case .math: return max(1, progression.mathLevel)
        default:    return 1
        }
    }

    private var isPi: Bool { mode == .pi }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: MDSpacing.lg) {
                // Header
                VStack(spacing: MDSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(mode.accentColor.opacity(0.12))
                            .frame(width: 64, height: 64)
                        ModeGlyph(mode: mode, size: 24, color: mode.accentColor)
                    }
                    Text(String(localized: "practice_mode_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "practice_mode_subtitle"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
                .padding(.top, MDSpacing.lg)

                // Picker
                VStack(spacing: MDSpacing.xs) {
                    Text(isPi
                         ? String(localized: "practice_start_digit_label")
                         : String(localized: "practice_start_level_label"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MDSpacing.md)

                    Picker("", selection: $selectedValue) {
                        ForEach(1...maxValue, id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .padding(.horizontal, MDSpacing.md)
                    .background(Color.mdSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, MDSpacing.md)
                }

                Spacer()

                MDButton(.primary, title: String(localized: "practice_start_action")) {
                    dismiss()
                    onStart(selectedValue)
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
        .onAppear {
            selectedValue = max(1, maxValue)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

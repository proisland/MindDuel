import SwiftUI

struct PiGameView: View {
    let username: String
    @StateObject private var engine = GameEngine()
    @State private var currentIndex = 0
    @State private var elapsedSeconds: Double = 0
    @State private var selectedDigit: Int? = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var showQuitModal = false

    @Environment(\.dismiss) private var dismiss

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var targetDigit: Int {
        guard currentIndex < PiData.digits.count else { return 0 }
        return PiData.digits[currentIndex]
    }

    private var piSequenceDisplay: String {
        let revealed = PiData.digits.prefix(currentIndex).map { String($0) }.joined()
        if currentIndex <= 10 {
            return "3." + revealed + "…"
        }
        let suffix = String(revealed.suffix(8))
        return "…" + suffix + "…"
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            switch engine.phase {
            case .roundOver:
                RoundEndView(correctCount: engine.correctCount) {
                    engine.restart()
                    currentIndex = 0
                    elapsedSeconds = 0
                    feedbackIsCorrect = nil
                    selectedDigit = nil
                } onHome: {
                    dismiss()
                }
            default:
                gameContent
            }

            if showQuitModal {
                QuitGameModal {
                    showQuitModal = false
                    engine.quit()
                } onContinue: {
                    showQuitModal = false
                }
            }
        }
        .onReceive(timer) { _ in
            handleTimerTick()
        }
        .animation(.easeInOut(duration: 0.2), value: showQuitModal)
    }

    private var gameContent: some View {
        VStack(spacing: 0) {
            MDTopBar(title: String(localized: "mode_pi"), leadingAction: { showQuitModal = true }) {
                MDAvatar(username: username, size: .sm)
            }

            ScrollView {
                VStack(spacing: MDSpacing.lg) {
                    ResourcePillRow(lives: engine.lives, skips: engine.skips)
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.top, MDSpacing.md)

                    piDisplayCard

                    digitGrid
                        .padding(.horizontal, MDSpacing.md)

                    SkipButton(elapsedSeconds: elapsedSeconds, onSkip: handleSkip)
                        .disabled(isInteractionBlocked)
                        .padding(.bottom, MDSpacing.xl)
                }
            }
        }
        .overlay {
            if case .waitingAfterSkip = engine.phase {
                waitingOverlay
            }
        }
    }

    private var piDisplayCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "pi_digits_guessed"), currentIndex))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText2)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(piSequenceDisplay)
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.mdText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, MDSpacing.sm)
        }
        .padding(.horizontal, MDSpacing.md)
    }

    private var digitGrid: some View {
        let digits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(digits, id: \.self) { digit in
                DigitButton(
                    digit: digit,
                    feedbackState: buttonFeedbackState(for: digit)
                ) {
                    handleDigitTap(digit)
                }
                .disabled(isInteractionBlocked)
            }
        }
    }

    private var waitingOverlay: some View {
        Color.mdBg.opacity(0.85)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: MDSpacing.sm) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.mdAccent)
                    Text(String(localized: "tap_to_continue_hint"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText2)
                }
            }
            .onTapGesture {
                currentIndex += 1
                elapsedSeconds = 0
                engine.resumeAfterSkip()
            }
    }

    private var isInteractionBlocked: Bool {
        switch engine.phase {
        case .playing: return feedbackIsCorrect != nil
        default: return true
        }
    }

    private func buttonFeedbackState(for digit: Int) -> DigitFeedbackState {
        guard selectedDigit == digit else { return .idle }
        switch feedbackIsCorrect {
        case true: return .correct
        case false: return .wrong
        case nil: return .idle
        }
    }

    private func handleDigitTap(_ digit: Int) {
        guard case .playing = engine.phase, feedbackIsCorrect == nil else { return }
        selectedDigit = digit
        let correct = digit == targetDigit
        feedbackIsCorrect = correct

        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                engine.recordCorrect()
                currentIndex += 1
                elapsedSeconds = 0
            } else {
                engine.recordWrong()
            }
            selectedDigit = nil
            feedbackIsCorrect = nil
        }
    }

    private func handleSkip() {
        guard case .playing = engine.phase else { return }
        elapsedSeconds = 0
        currentIndex += 1
        engine.useSkip()
    }

    private func handleTimerTick() {
        guard case .playing = engine.phase, feedbackIsCorrect == nil else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 {
            handleSkip()
        }
    }
}

enum DigitFeedbackState {
    case idle, correct, wrong
}

private struct DigitButton: View {
    let digit: Int
    let feedbackState: DigitFeedbackState
    let action: () -> Void

    private var bgColor: Color {
        switch feedbackState {
        case .idle: return .mdSurface2
        case .correct: return .mdGreenSoft
        case .wrong: return .mdRedSoft
        }
    }

    private var borderColor: Color {
        switch feedbackState {
        case .idle: return .mdBorder2
        case .correct: return .mdGreen
        case .wrong: return .mdRed
        }
    }

    private var textColor: Color {
        switch feedbackState {
        case .idle: return .mdText
        case .correct: return .mdGreen
        case .wrong: return .mdRed
        }
    }

    var body: some View {
        Button(action: action) {
            Text("\(digit)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(bgColor)
                .clipShape(Circle())
                .overlay(Circle().stroke(borderColor, lineWidth: 1))
        }
        .animation(.easeInOut(duration: 0.15), value: feedbackState == .idle)
    }
}

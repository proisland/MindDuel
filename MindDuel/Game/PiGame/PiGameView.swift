import SwiftUI

struct PiGameView: View {
    let username: String
    @StateObject private var engine = GameEngine()
    @State private var currentIndex = 0
    @State private var elapsedSeconds: Double = 0
    @State private var totalAnswerTime: Double = 0
    @State private var selectedDigit: Int? = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var showQuitModal = false

    private var avgTimeSeconds: Double {
        engine.correctCount > 0 ? totalAnswerTime / Double(engine.correctCount) : 0
    }

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
        return "…" + String(revealed.suffix(8)) + "…"
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            if engine.isRoundOver {
                RoundEndView(correctCount: engine.correctCount, avgTimeSeconds: avgTimeSeconds) {
                    engine.restart()
                    currentIndex = 0
                    elapsedSeconds = 0
                    totalAnswerTime = 0
                    feedbackIsCorrect = nil
                    selectedDigit = nil
                } onHome: {
                    dismiss()
                }
            } else {
                gameScreen
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

    // MARK: – Layout

    private var gameScreen: some View {
        VStack(spacing: 0) {
            MDTopBar(title: String(localized: "mode_pi"), leadingAction: { showQuitModal = true }) {
                MDAvatar(username: username, size: .sm)
            }

            ResourcePillRow(lives: engine.lives, skips: engine.skips)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

            questionCard
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.lg)

            digitGrid
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

            Spacer()

            SkipButton(elapsedSeconds: elapsedSeconds, onSkip: handleSkip)
                .disabled(isInteractionBlocked)
                .padding(.bottom, MDSpacing.xl)
        }
        .overlay {
            if engine.isWaitingAfterSkip {
                waitingOverlay
            }
        }
    }

    private var questionCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "pi_digits_guessed"), currentIndex))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText2)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(piSequenceDisplay)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.mdText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, MDSpacing.sm)
        }
    }

    private var digitGrid: some View {
        let digits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(digits, id: \.self) { digit in
                DigitButton(digit: digit, feedbackState: buttonFeedbackState(for: digit)) {
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

    // MARK: – State helpers

    private var isInteractionBlocked: Bool {
        engine.isRoundOver || engine.isWaitingAfterSkip || feedbackIsCorrect != nil
    }

    private func buttonFeedbackState(for digit: Int) -> DigitFeedbackState {
        guard let sel = selectedDigit, sel == digit else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    // MARK: – Actions

    private func handleDigitTap(_ digit: Int) {
        guard !isInteractionBlocked else { return }
        selectedDigit = digit
        let correct = digit == targetDigit
        feedbackIsCorrect = correct
        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                totalAnswerTime += elapsedSeconds
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
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip else { return }
        elapsedSeconds = 0
        currentIndex += 1
        engine.useSkip()
    }

    private func handleTimerTick() {
        guard !isInteractionBlocked else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 { handleSkip() }
    }
}

// MARK: – Digit button

enum DigitFeedbackState: Equatable { case idle, correct, wrong }

private struct DigitButton: View {
    let digit: Int
    let feedbackState: DigitFeedbackState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(digit)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(bgColor)
                .clipShape(Circle())
                .overlay(Circle().stroke(borderColor, lineWidth: 1.5))
        }
        .animation(.easeInOut(duration: 0.15), value: feedbackState)
    }

    private var bgColor: Color {
        switch feedbackState {
        case .idle:    return .mdSurface2
        case .correct: return .mdGreenSoft
        case .wrong:   return .mdRedSoft
        }
    }
    private var borderColor: Color {
        switch feedbackState {
        case .idle:    return .mdBorder2
        case .correct: return .mdGreen
        case .wrong:   return .mdRed
        }
    }
    private var labelColor: Color {
        switch feedbackState {
        case .idle:    return .mdText
        case .correct: return .mdGreen
        case .wrong:   return .mdRed
        }
    }
}

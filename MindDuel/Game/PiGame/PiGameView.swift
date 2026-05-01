import SwiftUI

struct PiGameView: View {
    let username: String
    var resumeRoomID: String? = nil

    @StateObject private var engine      = GameEngine()
    @StateObject private var progression = ProgressionStore.shared
    @State private var currentIndex      = 0
    @State private var elapsedSeconds:   Double = 0
    @State private var totalAnswerTime:  Double = 0
    @State private var selectedDigit:    Int?   = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var showQuitModal     = false
    @State private var roundResult:      ProgressionStore.RoundResult? = nil
    @State private var sessionStartIndex: Int = 0

    @Environment(\.dismiss) private var dismiss

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// The first digit index of the user's current Pi level (level 1 → 0, level 2 → 50, …).
    /// This ensures starting a Pi game at a given level always begins at that level's boundary,
    /// matching the level shown on the home screen.
    private var levelStartIndex: Int { max(0, (ProgressionStore.shared.piLevel - 1) * 50) }

    private var startIndex: Int { sessionStartIndex }

    private var targetDigit: Int {
        let idx = startIndex + currentIndex
        guard idx < PiData.digits.count else { return 0 }
        return PiData.digits[idx]
    }

    private var piSequenceDisplay: String {
        let absIndex = startIndex + currentIndex
        let revealed = PiData.digits.prefix(absIndex).map { String($0) }.joined()
        if absIndex <= 10 {
            return "3." + revealed + "…"
        }
        return "…" + String(revealed.suffix(8)) + "…"
    }

    private var avgTime: Double {
        engine.correctCount > 0 ? totalAnswerTime / Double(engine.correctCount) : 0
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            if engine.isRoundOver, let result = roundResult {
                RoundEndView(
                    correctCount: engine.correctCount,
                    avgTimeSeconds: avgTime,
                    score: result.score,
                    isPersonalBest: result.isPersonalBest
                ) {
                    resetRound()
                } onHome: {
                    dismiss()
                }
            } else {
                gameScreen
            }

            if showQuitModal {
                QuitGameModal(
                    onQuit: {
                        showQuitModal = false
                        finaliseRound(won: false)
                        engine.quit()
                    },
                    onContinue: {
                        showQuitModal = false
                    },
                    onSave: {
                        showQuitModal = false
                        saveSessionAndExit()
                    }
                )
            }
        }
        .onAppear { restoreOrStartFresh() }
        .onReceive(timer) { _ in handleTimerTick() }
        .animation(.easeInOut(duration: 0.2), value: showQuitModal)
        .onChange(of: engine.isRoundOver, perform: { over in
            if over && roundResult == nil { finaliseRound(won: false) }
        })
    }

    // MARK: – Session restore / save

    private func restoreOrStartFresh() {
        if let id = resumeRoomID,
           let room = MultiplayerStore.shared.popStandaloneSolo(roomID: id),
           let me = room.players.first(where: { $0.isYou }) {
            // Resume saved session: start at the saved digit position, currentIndex is 0
            sessionStartIndex = room.myPiDigitIndex
            currentIndex = 0
            engine.restoreState(lives: me.lives, skips: me.skips, correctCount: me.correctCount)
            return
        }
        // Fresh game: start at the boundary of the user's current Pi level
        sessionStartIndex = levelStartIndex
    }

    private func saveSessionAndExit() {
        let absoluteDigit = sessionStartIndex + currentIndex
        // Apply round side-effects (score / piPosition) before saving exit
        finaliseRound(won: false)
        _ = MultiplayerStore.shared.saveStandaloneSoloPi(
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: roundResult?.score ?? 0,
            correctCount: engine.correctCount,
            currentDigit: absoluteDigit
        )
        engine.quit()
        dismiss()
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
            if engine.isWaitingAfterSkip { waitingOverlay }
        }
        .overlay(alignment: .top) {
            if progression.isQuotaExhausted {
                quotaExhaustedBanner
                    .padding(.top, 60)
                    .padding(.horizontal, MDSpacing.md)
            }
        }
    }

    private var questionCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "pi_digits_guessed"), startIndex + currentIndex))
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
        let digits  = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(digits, id: \.self) { digit in
                DigitButton(digit: digit, feedbackState: buttonFeedbackState(for: digit)) {
                    handleDigitTap(digit)
                }
                .disabled(isInteractionBlocked || progression.isQuotaExhausted)
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

    private var quotaExhaustedBanner: some View {
        HStack(spacing: MDSpacing.sm) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.mdAmber)
            Text(String(localized: "quota_exhausted_message"))
                .mdStyle(.bodyMd)
            Spacer()
            MDButton(.ghost, title: String(localized: "back_to_home_action")) {
                finaliseRound(won: true)
                dismiss()
            }
            .frame(width: 80)
        }
        .padding(MDSpacing.md)
        .background(Color.mdAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        guard !isInteractionBlocked, !progression.isQuotaExhausted else { return }
        progression.consumeQuestion()
        selectedDigit = digit
        let correct   = digit == targetDigit
        feedbackIsCorrect = correct

        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                totalAnswerTime += elapsedSeconds
                engine.recordCorrect()
                currentIndex   += 1
                elapsedSeconds  = 0
            } else {
                engine.recordWrong()
            }
            selectedDigit     = nil
            feedbackIsCorrect = nil
        }
    }

    private func handleSkip() {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip else { return }
        elapsedSeconds  = 0
        currentIndex   += 1
        engine.useSkip()
    }

    private func handleTimerTick() {
        guard !isInteractionBlocked, !progression.isQuotaExhausted else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 { handleSkip() }
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        roundResult = progression.applyPiRound(
            correctCount: engine.correctCount,
            avgTime: avgTime,
            won: won
        )
    }

    private func resetRound() {
        engine.restart()
        sessionStartIndex = levelStartIndex
        currentIndex      = 0
        elapsedSeconds    = 0
        totalAnswerTime   = 0
        feedbackIsCorrect = nil
        selectedDigit     = nil
        roundResult       = nil
    }
}

// MARK: – Digit button

enum DigitFeedbackState: Equatable { case idle, correct, wrong }

struct DigitButton: View {
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
                .overlay(Circle().stroke(borderColor, lineWidth: feedbackState == .idle ? 0 : 1.5))
        }
        .buttonStyle(.plain)
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
        case .idle:    return .clear
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

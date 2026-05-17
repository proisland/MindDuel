import SwiftUI

struct PiGameView: View {
    let username: String
    var resumeRoomID: String? = nil
    let isPractice: Bool
    let practiceStartDigit: Int

    @StateObject private var engine      = GameEngine()
    @ObservedObject private var progression = ProgressionStore.shared
    @State private var currentIndex      = 0
    @State private var elapsedSeconds:   Double = 0
    @State private var totalAnswerTime:  Double = 0
    @State private var selectedDigit:    Int?   = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var revealCorrectDigit: Int? = nil
    @State private var showQuitModal     = false
    @State private var roundResult:      ProgressionStore.RoundResult? = nil
    @State private var sessionStartIndex: Int = 0

    @AppStorage("game.difficulty") private var difficultyRaw: String = "normal"
    private var difficulty: GameDifficulty { GameDifficulty(rawValue: difficultyRaw) ?? .normal }

    @StateObject private var sessionService = GameSessionService()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(username: String, resumeRoomID: String? = nil,
         isPractice: Bool = false, practiceStartDigit: Int = 0) {
        self.username = username
        self.resumeRoomID = resumeRoomID
        self.isPractice = isPractice
        self.practiceStartDigit = practiceStartDigit
        if let id = resumeRoomID,
           let room = MultiplayerStore.shared.backgroundRooms.first(where: { $0.id == id }),
           let me = room.players.first(where: { $0.isYou }) {
            _engine = StateObject(wrappedValue: GameEngine(lives: me.lives, skips: me.skips, correctCount: me.correctCount))
        }
    }

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
                    onSave: isPractice ? nil : {
                        showQuitModal = false
                        saveSessionAndExit()
                    }
                )
            }
        }
        .onAppear {
            if isPractice {
                sessionStartIndex = practiceStartDigit
            } else {
                restoreOrStartFresh()
                Task { try? await sessionService.startSession(mode: "pi") }
            }
        }
        .onDisappear {
            guard !isPractice else { return }
            autoSaveIfInProgress()
            Task { try? await sessionService.endSession() }
        }
        .onReceive(timer) { _ in handleTimerTick() }
        .animation(.easeInOut(duration: 0.2), value: showQuitModal)
        .onChange(of: engine.isRoundOver, perform: { over in
            if over && roundResult == nil { finaliseRound(won: false) }
        })
    }

    // MARK: – Session restore / save

    private func autoSaveIfInProgress() {
        // Catches iOS swipe-to-dismiss gestures that bypass the quit modal.
        // Don't auto-save fresh / finished rounds, and don't double-save when the
        // user just chose Save & Exit from the modal (saveSessionAndExit set roundResult).
        guard !engine.isRoundOver, roundResult == nil,
              engine.correctCount > 0 || engine.lives < 5 || engine.skips < 5 else { return }
        let absoluteDigit = sessionStartIndex + currentIndex
        _ = MultiplayerStore.shared.saveStandaloneSoloPi(
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: 0,
            correctCount: engine.correctCount,
            currentDigit: absoluteDigit
        )
    }

    private func restoreOrStartFresh() {
        if let id = resumeRoomID,
           let room = MultiplayerStore.shared.popStandaloneSolo(roomID: id),
           let me = room.players.first(where: { $0.isYou }) {
            // Resume saved session: start at the saved digit position, currentIndex is 0
            sessionStartIndex = room.myPiDigitIndex
            currentIndex = 0
            engine.restoreState(lives: me.lives, skips: me.skips, correctCount: me.correctCount)
            // Re-save immediately so the session survives a crash or early dismiss.
            _ = MultiplayerStore.shared.saveStandaloneSoloPi(
                ownUsername: username, lives: me.lives, skips: me.skips,
                score: 0, correctCount: me.correctCount, currentDigit: room.myPiDigitIndex
            )
            return
        }
        // Fresh game: start at the boundary of the user's current Pi level
        sessionStartIndex = levelStartIndex
    }

    private func saveSessionAndExit() {
        // Save mid-session state. Don't call finaliseRound here — that would apply
        // a piPosition rollback and add the partial score to piBestScore now,
        // and then again when the resumed round eventually ends (double-counting).
        // The score field on the saved room is informational only; the real total
        // is computed by finaliseRound when the resumed round actually finishes.
        let absoluteDigit = sessionStartIndex + currentIndex
        _ = MultiplayerStore.shared.saveStandaloneSoloPi(
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: 0,
            correctCount: engine.correctCount,
            currentDigit: absoluteDigit
        )
        // Mark roundResult set so onChange(isRoundOver) doesn't finalise again
        // when we quit the engine.
        roundResult = ProgressionStore.RoundResult(score: 0, isPersonalBest: false)
        engine.quit()
        dismiss()
    }

    // MARK: – Layout

    private var gameScreen: some View {
        VStack(spacing: 0) {
            MDTopBar(
                title: isPractice
                    ? String(localized: "practice_mode_title")
                    : String(localized: "mode_pi"),
                leadingAction: {
                    Haptics.trigger(.modalOpen)
                    showQuitModal = true
                }
            ) {
                MDAvatar(username: username, size: .sm)
            }

            ResourcePillRow(lives: engine.lives, skips: engine.skips)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

            CountdownTimer(elapsedSeconds: elapsedSeconds, maxSeconds: difficulty.timerSeconds)
                .padding(.top, MDSpacing.sm)

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
        .animation(.easeOut(duration: 0.2), value: currentIndex)
        .overlay {
            if engine.isWaitingAfterSkip { waitingOverlay }
        }
        .overlay(alignment: .top) {
            if !isPractice && progression.isQuotaExhausted {
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
        .id(currentIndex)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var digitGrid: some View {
        let digits  = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(digits, id: \.self) { digit in
                DigitButton(digit: digit, feedbackState: buttonFeedbackState(for: digit)) {
                    handleDigitTap(digit)
                }
                .disabled(isInteractionBlocked || (!isPractice && progression.isQuotaExhausted))
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
        if let reveal = revealCorrectDigit, digit == reveal { return .reveal }
        guard let sel = selectedDigit, sel == digit else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    // MARK: – Actions

    private func handleDigitTap(_ digit: Int) {
        guard !isInteractionBlocked,
              isPractice || !progression.isQuotaExhausted else { return }
        if !isPractice { progression.consumeQuestion() }
        selectedDigit = digit
        let correct   = digit == targetDigit
        feedbackIsCorrect = correct

        if !isPractice {
            let questionId = "pi-\(startIndex + currentIndex)"
            let answeredAt = ISO8601DateFormatter.ms.string(from: Date())
            Task { try? await sessionService.submitAnswer(answeredAt: answeredAt,
                                                         questionId: questionId,
                                                         answer: String(digit),
                                                         isCorrect: correct) }
        }

        Task {
            if correct {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if !isPractice {
                    totalAnswerTime += elapsedSeconds
                    progression.recordCorrectAnswerTime(elapsedSeconds)
                    progression.advancePiPosition(toFrontier: sessionStartIndex + currentIndex + 1)
                }
                engine.recordCorrect()
                currentIndex   += 1
                elapsedSeconds  = 0
            } else {
                try? await Task.sleep(nanoseconds: 300_000_000)
                engine.recordWrong()
                if isPractice {
                    revealCorrectDigit = targetDigit
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    revealCorrectDigit = nil
                }
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
        guard !isInteractionBlocked,
              isPractice || !progression.isQuotaExhausted else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, difficulty.timerSeconds)
        if !isPractice, elapsedSeconds >= difficulty.timerSeconds { handleSkip() }
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        if !isPractice {
            roundResult = progression.applyPiRound(
                correctCount: engine.correctCount,
                avgTime: avgTime,
                won: won,
                difficultyMultiplier: difficulty.scoreMultiplier
            )
            Task { try? await sessionService.endSession() }
        } else {
            roundResult = ProgressionStore.RoundResult(score: 0, isPersonalBest: false)
        }
    }

    private func resetRound() {
        engine.restart()
        sessionStartIndex = isPractice ? practiceStartDigit : levelStartIndex
        currentIndex      = 0
        elapsedSeconds    = 0
        totalAnswerTime   = 0
        feedbackIsCorrect = nil
        selectedDigit     = nil
        revealCorrectDigit = nil
        roundResult       = nil
    }
}

// MARK: – Digit button

enum DigitFeedbackState: Equatable { case idle, correct, wrong, reveal }

struct DigitButton: View {
    let digit: Int
    let feedbackState: DigitFeedbackState
    let action: () -> Void

    @State private var shakeAttempts = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text("\(digit)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor, lineWidth: feedbackState == .idle ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(feedbackState == .correct && !reduceMotion ? 1.05 : 1.0)
        .modifier(ShakeEffect(animatableData: CGFloat(shakeAttempts)))
        .animation(.spring(response: 0.22, dampingFraction: 0.45), value: feedbackState == .correct)
        .animation(.easeInOut(duration: 0.15), value: feedbackState)
        .onChange(of: feedbackState) { state in
            switch state {
            case .correct:
                Haptics.trigger(.correct)
            case .wrong:
                Haptics.trigger(.wrong)
                if !reduceMotion {
                    withAnimation(.linear(duration: 0.3)) { shakeAttempts += 1 }
                }
            case .reveal, .idle:
                break
            }
        }
    }

    private var bgColor: Color {
        switch feedbackState {
        case .idle:             return .mdSurface2
        case .correct, .reveal: return .mdGreenSoft
        case .wrong:            return .mdRedSoft
        }
    }
    private var borderColor: Color {
        switch feedbackState {
        case .idle:             return .clear
        case .correct, .reveal: return .mdGreen
        case .wrong:            return .mdRed
        }
    }
    private var labelColor: Color {
        switch feedbackState {
        case .idle:             return .mdText
        case .correct, .reveal: return .mdGreen
        case .wrong:            return .mdRed
        }
    }
}

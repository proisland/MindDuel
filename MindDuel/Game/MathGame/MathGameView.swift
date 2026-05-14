import SwiftUI

struct MathGameView: View {
    let username: String
    let resumeRoomID: String?
    let isPractice: Bool
    let practiceStartLevel: Int

    @StateObject private var engine      = GameEngine()
    @ObservedObject private var progression = ProgressionStore.shared
    @State private var problem:           MathProblem
    @State private var problemCount      = 1
    @State private var elapsedSeconds:   Double = 0
    @State private var totalAnswerTime:  Double = 0
    @State private var selectedIndex:    Int?   = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var revealCorrectIndex: Int? = nil
    @State private var showQuitModal     = false
    @State private var roundResult:      ProgressionStore.RoundResult? = nil
    @State private var startLevel:       Int

    @Environment(\.dismiss) private var dismiss

    @StateObject private var sessionService = GameSessionService()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(username: String, resumeRoomID: String? = nil,
         isPractice: Bool = false, practiceStartLevel: Int = 1) {
        self.username = username
        self.resumeRoomID = resumeRoomID
        self.isPractice = isPractice
        self.practiceStartLevel = practiceStartLevel
        let lvl = isPractice ? practiceStartLevel : ProgressionStore.shared.mathLevel
        _startLevel = State(initialValue: lvl)
        _problem    = State(initialValue: MathProblemGenerator.generate(level: lvl))
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
                gameContent
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
            guard !isPractice else { return }
            restoreSavedSessionIfNeeded()
            Task { try? await sessionService.startSession(mode: "math", startPosition: startLevel) }
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

    private func restoreSavedSessionIfNeeded() {
        guard let id = resumeRoomID,
              let room = MultiplayerStore.shared.popStandaloneSolo(roomID: id),
              let me = room.players.first(where: { $0.isYou }) else { return }
        startLevel = max(1, room.startLevel)
        problem    = MathProblemGenerator.generate(level: progression.mathLevel)
        problemCount = max(1, me.correctCount + 1)
        engine.restoreState(lives: me.lives, skips: me.skips, correctCount: me.correctCount)
    }

    private func saveSessionAndExit() {
        // Save mid-session state without finalising — see PiGameView for why.
        _ = MultiplayerStore.shared.saveStandaloneSoloMath(
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: 0,
            correctCount: engine.correctCount,
            startLevel: startLevel
        )
        roundResult = ProgressionStore.RoundResult(score: 0, isPersonalBest: false)
        engine.quit()
        dismiss()
    }

    private func autoSaveIfInProgress() {
        guard !engine.isRoundOver, roundResult == nil,
              engine.correctCount > 0 || engine.lives < 5 || engine.skips < 5 else { return }
        _ = MultiplayerStore.shared.saveStandaloneSoloMath(
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: 0,
            correctCount: engine.correctCount,
            startLevel: startLevel
        )
    }

    // MARK: – Layout

    private var gameContent: some View {
        VStack(spacing: 0) {
            MDTopBar(
                title: isPractice
                    ? String(localized: "practice_mode_title")
                    : String(localized: "mode_math"),
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

            CountdownTimer(elapsedSeconds: elapsedSeconds)
                .padding(.top, MDSpacing.sm)

            problemCard
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.lg)

            answerGrid
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

            Spacer()

            SkipButton(elapsedSeconds: elapsedSeconds, onSkip: handleSkip)
                .disabled(isInteractionBlocked)
                .padding(.bottom, MDSpacing.xl)
        }
        .animation(.easeOut(duration: 0.2), value: problemCount)
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

    private var problemCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "math_level_problem"),
                            isPractice ? startLevel : progression.mathLevel, problemCount))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText2)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(problem.display)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.mdText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, MDSpacing.sm)
        }
        .id(problemCount)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var answerGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 2)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(problem.options.indices, id: \.self) { index in
                AnswerButton(
                    label: "\(problem.options[index])",
                    feedbackState: answerFeedbackState(for: index)
                ) {
                    handleAnswerTap(index)
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
                        .foregroundStyle(Color.mdPink)
                    Text(String(localized: "tap_to_continue_hint"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText2)
                }
            }
            .onTapGesture {
                nextProblem()
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

    private func answerFeedbackState(for index: Int) -> AnswerFeedbackState {
        if let revealIdx = revealCorrectIndex, index == revealIdx { return .reveal }
        guard let sel = selectedIndex, sel == index else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    // MARK: – Actions

    private func handleAnswerTap(_ index: Int) {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip,
              feedbackIsCorrect == nil,
              isPractice || !progression.isQuotaExhausted else { return }
        if !isPractice { progression.consumeQuestion() }
        selectedIndex     = index
        let correct       = problem.options[index] == problem.correctAnswer
        feedbackIsCorrect = correct

        if !isPractice {
            let answeredAt = ISO8601DateFormatter.ms.string(from: Date())
            Task { try? await sessionService.submitAnswer(answeredAt: answeredAt,
                                                         questionId: "math-\(problemCount)",
                                                         answer: "\(problem.options[index])",
                                                         isCorrect: correct) }
        }

        Task {
            if correct {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if !isPractice {
                    totalAnswerTime += elapsedSeconds
                    progression.recordCorrectAnswerTime(elapsedSeconds, mode: .math)
                    progression.advanceMathLevel()
                }
                engine.recordCorrect()
            } else {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !isPractice {
                    progression.recordWrongAnswer(mode: .math)
                }
                engine.recordWrong()
                if isPractice {
                    // reveal correct answer for 1.5 s
                    let correctIdx = problem.options.firstIndex(of: problem.correctAnswer)
                    revealCorrectIndex = correctIdx
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    revealCorrectIndex = nil
                }
            }
            guard !engine.isRoundOver else {
                selectedIndex = nil; feedbackIsCorrect = nil; return
            }
            nextProblem()
            selectedIndex = nil; feedbackIsCorrect = nil
        }
    }

    private func handleSkip() {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip else { return }
        elapsedSeconds = 0
        engine.useSkip()
    }

    private func handleTimerTick() {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip,
              feedbackIsCorrect == nil, isPractice || !progression.isQuotaExhausted else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if !isPractice, elapsedSeconds >= 10.0 { handleSkip() }
    }

    private func nextProblem() {
        let lvl = isPractice ? startLevel : progression.mathLevel
        problem        = MathProblemGenerator.generate(level: lvl)
        problemCount  += 1
        elapsedSeconds = 0
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        if !isPractice {
            Task { try? await sessionService.endSession() }
            roundResult = progression.applyMathRound(
                correctCount: engine.correctCount,
                level: startLevel,
                avgTime: avgTime,
                won: won
            )
        } else {
            roundResult = ProgressionStore.RoundResult(score: 0, isPersonalBest: false)
        }
    }

    private func resetRound() {
        let lvl    = isPractice ? practiceStartLevel : progression.mathLevel
        startLevel = lvl
        problem    = MathProblemGenerator.generate(level: lvl)
        problemCount      = 1
        elapsedSeconds    = 0
        totalAnswerTime   = 0
        feedbackIsCorrect = nil
        selectedIndex     = nil
        revealCorrectIndex = nil
        roundResult       = nil
        engine.restart()
    }
}

// MARK: – Answer button

enum AnswerFeedbackState: Equatable { case idle, correct, wrong, reveal }

struct AnswerButton: View {
    let label: String
    let feedbackState: AnswerFeedbackState
    let action: () -> Void

    @State private var shakeAttempts = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textColor)
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
        case .idle:           return .mdSurface2
        case .correct, .reveal: return .mdGreenSoft
        case .wrong:          return .mdRedSoft
        }
    }
    private var borderColor: Color {
        switch feedbackState {
        case .idle:           return .clear
        case .correct, .reveal: return .mdGreen
        case .wrong:          return .mdRed
        }
    }
    private var textColor: Color {
        switch feedbackState {
        case .idle:           return .mdText
        case .correct, .reveal: return .mdGreen
        case .wrong:          return .mdRed
        }
    }
}

// MARK: – Shake animation

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 5
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

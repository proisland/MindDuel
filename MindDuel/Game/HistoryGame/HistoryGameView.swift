import SwiftUI

/// #59: solo history round. Mirrors BrainTrainingGameView/ScienceGameView.
struct HistoryGameView: View {
    let username: String

    @StateObject private var engine          = GameEngine()
    @ObservedObject private var progression  = ProgressionStore.shared
    @State private var problem:               HistoryProblem
    @State private var problemCount         = 1
    @State private var elapsedSeconds:      Double = 0
    @State private var totalAnswerTime:     Double = 0
    @State private var selectedIndex:       Int?   = nil
    @State private var feedbackIsCorrect:   Bool?  = nil
    @State private var showQuitModal        = false
    @State private var roundResult:         ProgressionStore.RoundResult? = nil
    @State private var startLevel:          Int

    @Environment(\.dismiss) private var dismiss
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(username: String) {
        self.username = username
        let lvl = ProgressionStore.shared.historyLevel
        _startLevel = State(initialValue: lvl)
        _problem    = State(initialValue: HistoryProblemGenerator.generate(level: lvl))
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
                ) { resetRound() } onHome: { dismiss() }
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
                    onContinue: { showQuitModal = false },
                    onSave: {
                        showQuitModal = false
                        dismiss()
                    }
                )
            }
        }
        .onReceive(timer) { _ in handleTimerTick() }
        .onChange(of: engine.isRoundOver) { over in
            if over && roundResult == nil { finaliseRound(won: false) }
        }
    }

    private var gameContent: some View {
        VStack(spacing: 0) {
            MDTopBar(title: String(localized: "mode_history"),
                     leadingAction: { showQuitModal = true }) {
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
        .overlay { if engine.isWaitingAfterSkip { waitingOverlay } }
    }

    private var problemCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "history_level_problem"),
                            progression.historyLevel, problemCount))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText2)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(HistoryProblemGenerator.curriculumLabel(forLevel: progression.historyLevel))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdText3)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(problem.prompt)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.mdText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, MDSpacing.sm)
        }
    }

    private var answerGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 2)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(problem.options.indices, id: \.self) { index in
                AnswerButton(
                    label: problem.options[index],
                    feedbackState: answerFeedbackState(for: index)
                ) { handleAnswerTap(index) }
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
                        .foregroundStyle(Color.mdRed)
                    Text(String(localized: "tap_to_continue_hint"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText2)
                }
            }
            .onTapGesture { nextProblem(); engine.resumeAfterSkip() }
    }

    private var isInteractionBlocked: Bool {
        engine.isRoundOver || engine.isWaitingAfterSkip || feedbackIsCorrect != nil
    }

    private func answerFeedbackState(for index: Int) -> AnswerFeedbackState {
        guard let sel = selectedIndex, sel == index else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    private func handleAnswerTap(_ index: Int) {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip,
              feedbackIsCorrect == nil, !progression.isQuotaExhausted else { return }
        progression.consumeQuestion()
        selectedIndex     = index
        let correct       = problem.options[index] == problem.correctAnswer
        feedbackIsCorrect = correct

        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                totalAnswerTime += elapsedSeconds
                progression.recordCorrectAnswerTime(elapsedSeconds, mode: .history)
                engine.recordCorrect()
                progression.advanceHistoryLevel()
            } else {
                progression.recordWrongAnswer(mode: .history)
                engine.recordWrong()
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
              feedbackIsCorrect == nil, !progression.isQuotaExhausted else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 { handleSkip() }
    }

    private func nextProblem() {
        problem = HistoryProblemGenerator.generate(level: progression.historyLevel)
        problemCount += 1
        elapsedSeconds = 0
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        roundResult = progression.applyHistoryRound(
            correctCount: engine.correctCount,
            level: startLevel,
            avgTime: avgTime,
            won: won
        )
    }

    private func resetRound() {
        let lvl    = progression.historyLevel
        startLevel = lvl
        problem    = HistoryProblemGenerator.generate(level: lvl)
        problemCount = 1; elapsedSeconds = 0; totalAnswerTime = 0
        feedbackIsCorrect = nil; selectedIndex = nil; roundResult = nil
        engine.restart()
    }
}

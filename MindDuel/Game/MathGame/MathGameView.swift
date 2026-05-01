import SwiftUI

struct MathGameView: View {
    let username: String
    let resumeRoomID: String?

    @StateObject private var engine      = GameEngine()
    @StateObject private var progression = ProgressionStore.shared
    @State private var problem:           MathProblem
    @State private var problemCount      = 1
    @State private var elapsedSeconds:   Double = 0
    @State private var totalAnswerTime:  Double = 0
    @State private var selectedIndex:    Int?   = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var showQuitModal     = false
    @State private var roundResult:      ProgressionStore.RoundResult? = nil
    @State private var startLevel:       Int

    @Environment(\.dismiss) private var dismiss

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(username: String, resumeRoomID: String? = nil) {
        self.username = username
        self.resumeRoomID = resumeRoomID
        let lvl = ProgressionStore.shared.mathLevel
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
                    onSave: {
                        showQuitModal = false
                        saveSessionAndExit()
                    }
                )
            }
        }
        .onAppear { restoreSavedSessionIfNeeded() }
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
        finaliseRound(won: false)
        _ = MultiplayerStore.shared.saveStandaloneSoloMath(
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: roundResult?.score ?? 0,
            correctCount: engine.correctCount,
            startLevel: startLevel
        )
        engine.quit()
        dismiss()
    }

    // MARK: – Layout

    private var gameContent: some View {
        VStack(spacing: 0) {
            MDTopBar(title: String(localized: "mode_math"), leadingAction: { showQuitModal = true }) {
                MDAvatar(username: username, size: .sm)
            }

            ResourcePillRow(lives: engine.lives, skips: engine.skips)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

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

    private var problemCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "math_level_problem"),
                            progression.mathLevel, problemCount))
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
              feedbackIsCorrect == nil, !progression.isQuotaExhausted else { return }
        progression.consumeQuestion()
        selectedIndex     = index
        let correct       = problem.options[index] == problem.correctAnswer
        feedbackIsCorrect = correct

        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                totalAnswerTime += elapsedSeconds
                engine.recordCorrect()
                progression.advanceMathLevel()   // may increment level
            } else {
                engine.recordWrong()
            }
            guard !engine.isRoundOver else {
                selectedIndex     = nil
                feedbackIsCorrect = nil
                return
            }
            nextProblem()
            selectedIndex     = nil
            feedbackIsCorrect = nil
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
        problem        = MathProblemGenerator.generate(level: progression.mathLevel)
        problemCount  += 1
        elapsedSeconds = 0
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        roundResult = progression.applyMathRound(
            correctCount: engine.correctCount,
            level: startLevel,
            avgTime: avgTime,
            won: won
        )
    }

    private func resetRound() {
        let lvl    = progression.mathLevel
        startLevel = lvl
        problem    = MathProblemGenerator.generate(level: lvl)
        problemCount      = 1
        elapsedSeconds    = 0
        totalAnswerTime   = 0
        feedbackIsCorrect = nil
        selectedIndex     = nil
        roundResult       = nil
        engine.restart()
    }
}

// MARK: – Answer button

enum AnswerFeedbackState: Equatable { case idle, correct, wrong }

struct AnswerButton: View {
    let label: String
    let feedbackState: AnswerFeedbackState
    let action: () -> Void

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
    private var textColor: Color {
        switch feedbackState {
        case .idle:    return .mdText
        case .correct: return .mdGreen
        case .wrong:   return .mdRed
        }
    }
}

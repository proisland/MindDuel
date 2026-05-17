import SwiftUI

/// Unified game view for all multiple-choice modes (chemistry, geography,
/// brain training, science, history, physics, sport, grammar). Replaces the
/// 8 near-identical per-mode views that previously lived in their own folders.
struct StandardGameView: View {
    let mode: GameMode
    let username: String
    let resumeRoomID: String?

    @StateObject private var engine      = GameEngine()
    @ObservedObject private var progression = ProgressionStore.shared
    @State private var problem:           any GameProblem
    @State private var problemCount      = 1
    @State private var elapsedSeconds:   Double = 0
    @State private var totalAnswerTime:  Double = 0
    @State private var selectedIndex:    Int?   = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var showQuitModal     = false
    @State private var roundResult:      ProgressionStore.RoundResult? = nil
    @State private var startLevel:       Int
    @State private var hasRestoredSession = false

    @AppStorage("game.difficulty") private var difficultyRaw: String = "normal"
    private var difficulty: GameDifficulty { GameDifficulty(rawValue: difficultyRaw) ?? .normal }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionService = GameSessionService()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor init(mode: GameMode, username: String, resumeRoomID: String? = nil) {
        self.mode = mode
        self.username = username
        self.resumeRoomID = resumeRoomID
        let lvl = ProgressionStore.shared.level(for: mode)
        _startLevel = State(initialValue: lvl)
        Self.resetRoundHistory(mode: mode)
        _problem = State(initialValue: Self.generate(mode: mode, level: lvl))
        if resumeRoomID != nil {
            // Look up by mode rather than ID — the ID may have drifted after a re-save.
            let resumeMode = mode
            let savedRoom = MultiplayerStore.shared.backgroundRooms.first(where: { room in
                room.isStandaloneSolo && room.mode == resumeMode && room.serverModeSlug == nil
            })
            if let me = savedRoom?.players.first(where: { $0.isYou }) {
                _engine = StateObject(wrappedValue: GameEngine(lives: me.lives, skips: me.skips, correctCount: me.correctCount))
            }
        }
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
        .onAppear {
            restoreSavedSessionIfNeeded()
            Task { try? await sessionService.startSession(mode: mode.slug, startPosition: startLevel) }
        }
        .onDisappear {
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
        guard !hasRestoredSession, resumeRoomID != nil else { return }
        hasRestoredSession = true
        // Use mode-based lookup (ID may have drifted after a re-save).
        let room = MultiplayerStore.shared.backgroundRooms.first(where: {
            $0.isStandaloneSolo && $0.mode == mode && $0.serverModeSlug == nil
        })
        guard let room, let me = room.players.first(where: { $0.isYou }) else { return }
        startLevel   = max(1, room.startLevel)
        problem      = Self.generate(mode: mode, level: progression.level(for: mode))
        problemCount = max(1, me.correctCount + 1)
        engine.restoreState(lives: me.lives, skips: me.skips, correctCount: me.correctCount)
    }

    private func saveSessionAndExit() {
        _ = MultiplayerStore.shared.saveStandaloneSolo(
            mode: mode, ownUsername: username,
            lives: engine.lives, skips: engine.skips, score: 0,
            correctCount: engine.correctCount, startLevel: startLevel
        )
        roundResult = ProgressionStore.RoundResult(score: 0, isPersonalBest: false)
        engine.quit()
        dismiss()
    }

    private func autoSaveIfInProgress() {
        guard !engine.isRoundOver, roundResult == nil,
              engine.correctCount > 0 || engine.lives < 5 || engine.skips < 5 else { return }
        _ = MultiplayerStore.shared.saveStandaloneSolo(
            mode: mode, ownUsername: username,
            lives: engine.lives, skips: engine.skips, score: 0,
            correctCount: engine.correctCount, startLevel: startLevel
        )
    }

    // MARK: – Layout

    private var gameContent: some View {
        VStack(spacing: 0) {
            MDTopBar(title: String(localized: String.LocalizationValue(mode.titleKey)), leadingAction: {
                Haptics.trigger(.modalOpen)
                showQuitModal = true
            }) {
                MDAvatar(username: username, size: .sm)
            }

            ResourcePillRow(lives: engine.lives, skips: engine.skips)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

            CountdownTimer(elapsedSeconds: elapsedSeconds, maxSeconds: difficulty.timerSeconds)
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
                Text(String(format: String(localized: "game_level_problem"),
                            progression.level(for: mode), problemCount))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText2)
                    .frame(maxWidth: .infinity, alignment: .center)
                if let flag = problem.flag {
                    FlagView(emoji: flag, size: 72)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Text(verbatim: problem.prompt)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.mdText)
                    .multilineTextAlignment(.center)
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
                    label: problem.options[index],
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
                        .foregroundStyle(Color.mdAccent)
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
        let answeredAt    = ISO8601DateFormatter.ms.string(from: Date())
        Task { try? await sessionService.submitAnswer(answeredAt: answeredAt, questionId: "\(mode.slug)-\(problemCount)", answer: problem.options[index], isCorrect: correct) }

        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                totalAnswerTime += elapsedSeconds
                progression.recordCorrectAnswerTime(elapsedSeconds, mode: mode)
                engine.recordCorrect()
                progression.advance(mode: mode)
            } else {
                progression.recordWrongAnswer(mode: mode)
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
        elapsedSeconds = min(elapsedSeconds + 0.1, difficulty.timerSeconds)
        if elapsedSeconds >= difficulty.timerSeconds { handleSkip() }
    }

    private func nextProblem() {
        problem        = Self.generate(mode: mode, level: progression.level(for: mode))
        problemCount  += 1
        elapsedSeconds = 0
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        Task { try? await sessionService.endSession() }
        roundResult = progression.applyRound(
            mode: mode,
            correctCount: engine.correctCount,
            level: startLevel,
            avgTime: avgTime,
            won: won,
            difficultyMultiplier: difficulty.scoreMultiplier
        )
    }

    private func resetRound() {
        let lvl    = progression.level(for: mode)
        startLevel = lvl
        Self.resetRoundHistory(mode: mode)
        problem    = Self.generate(mode: mode, level: lvl)
        problemCount      = 1
        elapsedSeconds    = 0
        totalAnswerTime   = 0
        feedbackIsCorrect = nil
        selectedIndex     = nil
        roundResult       = nil
        engine.restart()
    }

    // MARK: – Generator dispatch

    private static func generate(mode: GameMode, level: Int) -> any GameProblem {
        switch mode {
        case .chemistry:     return ChemistryProblemGenerator.generate(level: level)
        case .geography:     return GeographyProblemGenerator.generate(level: level)
        case .brainTraining: return BrainTrainingProblemGenerator.generate(level: level)
        case .science:       return ScienceProblemGenerator.generate(level: level)
        case .history:       return HistoryProblemGenerator.generate(level: level)
        case .physics:       return PhysicsProblemGenerator.generate(level: level)
        case .sport:         return SportProblemGenerator.generate(level: level)
        case .grammar:       return GrammarProblemGenerator.generate(level: level)
        case .pi, .math:     return ChemistryProblemGenerator.generate(level: level)
        }
    }

    private static func resetRoundHistory(mode: GameMode) {
        switch mode {
        case .chemistry:     ChemistryProblemGenerator.resetRoundHistory()
        case .geography:     GeographyProblemGenerator.resetRoundHistory()
        case .brainTraining: BrainTrainingProblemGenerator.resetRoundHistory()
        case .science:       ScienceProblemGenerator.resetRoundHistory()
        case .history:       HistoryProblemGenerator.resetRoundHistory()
        case .physics:       PhysicsProblemGenerator.resetRoundHistory()
        case .sport:         SportProblemGenerator.resetRoundHistory()
        case .grammar:       GrammarProblemGenerator.resetRoundHistory()
        case .pi, .math:     break
        }
    }
}

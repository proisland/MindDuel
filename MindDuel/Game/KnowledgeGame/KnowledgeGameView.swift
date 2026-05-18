import SwiftUI

/// Generic question-pack game view for server-only modes (slugs that have no
/// `GameMode` enum case). Uses `QuestionPackCache` for questions and
/// `ProgressionStore` generic methods for level/score tracking.
struct KnowledgeGameView: View {
    let serverMode: ServerMode
    let username: String
    var resumeRoomID: String? = nil
    private let hasDirectResumeState: Bool

    @StateObject private var engine          = GameEngine()
    @ObservedObject private var progression  = ProgressionStore.shared
    @State private var currentQuestion:       APIQuestion?
    @State private var problemCount          = 1
    @State private var elapsedSeconds:       Double = 0
    @State private var totalAnswerTime:      Double = 0
    @State private var selectedIndex:        Int?   = nil
    @State private var feedbackIsCorrect:    Bool?  = nil
    @State private var showQuitModal         = false
    @State private var roundResult:          ProgressionStore.RoundResult? = nil
    @State private var startLevel:           Int
    @State private var feedbackTask:         Task<Void, Never>? = nil
    @State private var sessionEnded         = false
    @State private var hasRestoredSession   = false

    @AppStorage("game.difficulty") private var difficultyRaw: String = "normal"
    private var difficulty: GameDifficulty { GameDifficulty(rawValue: difficultyRaw) ?? .normal }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionService  = GameSessionService()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor init(serverMode: ServerMode, username: String, resumeRoomID: String? = nil,
         resumeLives: Int? = nil, resumeSkips: Int? = nil,
         resumeCorrectCount: Int? = nil, resumeStartLevel: Int? = nil) {
        self.serverMode   = serverMode
        self.username     = username
        self.resumeRoomID = resumeRoomID
        self.hasDirectResumeState = resumeLives != nil

        if let rsLevel = resumeStartLevel, let rsLives = resumeLives,
           let rsSkips = resumeSkips, let rsCount = resumeCorrectCount {
            let lvl = max(1, rsLevel)
            _startLevel      = State(initialValue: lvl)
            _problemCount    = State(initialValue: max(1, rsCount + 1))
            _currentQuestion = State(initialValue: KnowledgeProblemGenerator.generate(slug: serverMode.slug, level: lvl))
            _engine = StateObject(wrappedValue: GameEngine(lives: rsLives, skips: rsSkips, correctCount: rsCount))
        } else {
            let lvl = ProgressionStore.shared.level(forSlug: serverMode.slug)
            _startLevel      = State(initialValue: lvl)
            _currentQuestion = State(initialValue: KnowledgeProblemGenerator.generate(slug: serverMode.slug, level: lvl))
            if let id = resumeRoomID,
               let room = MultiplayerStore.shared.backgroundRooms.first(where: { $0.id == id }),
               let me = room.players.first(where: { $0.isYou }) {
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
                ) { resetRound() } onHome: { dismiss() }
            } else if currentQuestion == nil {
                noQuestionsView
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
                        saveAndExit()
                    }
                )
            }
        }
        .onAppear {
            restoreSavedSessionIfNeeded()
            Task { try? await sessionService.startSession(mode: serverMode.slug, startPosition: startLevel) }
        }
        .task {
            guard currentQuestion == nil else { return }
            await QuestionPackCache.shared.syncIfNeeded(modes: [serverMode.slug])
            let lvl = progression.level(forSlug: serverMode.slug)
            currentQuestion = KnowledgeProblemGenerator.generate(slug: serverMode.slug, level: lvl)
        }
        .onDisappear {
            feedbackTask?.cancel()
            autoSaveIfInProgress()
            endSessionOnce()
        }
        .onReceive(timer) { _ in handleTimerTick() }
        .onChange(of: engine.isRoundOver) { over in
            if over && roundResult == nil { finaliseRound(won: false) }
        }
    }

    // MARK: – Views

    private var noQuestionsView: some View {
        VStack(spacing: MDSpacing.md) {
            MDTopBar(title: serverMode.name, leadingAction: { dismiss() }) { EmptyView() }
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.mdText3)
            Text("Spørsmål lastes ned…")
                .mdStyle(.body)
                .foregroundStyle(Color.mdText2)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var gameContent: some View {
        VStack(spacing: 0) {
            MDTopBar(title: serverMode.name, leadingAction: {
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
        .overlay { if engine.isWaitingAfterSkip { waitingOverlay } }
    }

    private var problemCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "history_level_problem"),
                            progression.level(forSlug: serverMode.slug), problemCount))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText2)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(currentQuestion?.prompt ?? "")
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
        guard let q = currentQuestion else { return AnyView(EmptyView()) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 2)
        return AnyView(LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(q.options.indices, id: \.self) { index in
                AnswerButton(
                    label: q.options[index],
                    feedbackState: answerFeedbackState(for: index)
                ) { handleAnswerTap(index) }
                .disabled(isInteractionBlocked || progression.isQuotaExhausted)
            }
        })
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
            .onTapGesture { loadNextQuestion(); engine.resumeAfterSkip() }
    }

    private var isInteractionBlocked: Bool {
        engine.isRoundOver || engine.isWaitingAfterSkip || feedbackIsCorrect != nil
    }

    // MARK: – Logic

    private func answerFeedbackState(for index: Int) -> AnswerFeedbackState {
        guard let sel = selectedIndex, sel == index else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    private func handleAnswerTap(_ index: Int) {
        guard let q = currentQuestion,
              !engine.isRoundOver, !engine.isWaitingAfterSkip,
              feedbackIsCorrect == nil, !progression.isQuotaExhausted else { return }
        progression.consumeQuestion()
        selectedIndex     = index
        let correct       = q.options[index] == q.answer
        feedbackIsCorrect = correct
        let answeredAt = ISO8601DateFormatter.ms.string(from: Date())
        Task { try? await sessionService.submitAnswer(answeredAt: answeredAt, questionId: q.id, answer: q.options[index], isCorrect: correct) }

        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                KnowledgeProblemGenerator.recordCorrect(slug: serverMode.slug, questionId: q.id)
                totalAnswerTime += elapsedSeconds
                progression.recordCorrectAnswerTime(elapsedSeconds)
                engine.recordCorrect()
                progression.advanceGenericLevel(slug: serverMode.slug)
            } else {
                engine.recordWrong()
            }
            guard !engine.isRoundOver else {
                selectedIndex = nil; feedbackIsCorrect = nil; return
            }
            loadNextQuestion()
            selectedIndex = nil; feedbackIsCorrect = nil
        }
    }

    private func handleSkip() {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip else { return }
        elapsedSeconds = 0
        engine.useSkip()
    }

    private func handleTimerTick() {
        guard !showQuitModal else { return }
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip,
              feedbackIsCorrect == nil, !progression.isQuotaExhausted else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, difficulty.timerSeconds)
        if elapsedSeconds >= difficulty.timerSeconds { handleSkip() }
    }

    private func loadNextQuestion() {
        let lvl = progression.level(forSlug: serverMode.slug)
        currentQuestion = KnowledgeProblemGenerator.generate(slug: serverMode.slug, level: lvl)
        problemCount += 1
        elapsedSeconds = 0
    }

    private func endSessionOnce() {
        guard !sessionEnded else { return }
        sessionEnded = true
        Task { try? await sessionService.endSession() }
    }

    private func saveAndExit() {
        guard roundResult == nil else { return }
        endSessionOnce()
        _ = MultiplayerStore.shared.saveStandaloneSoloKnowledge(
            slug: serverMode.slug,
            name: serverMode.name,
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

    private func restoreSavedSessionIfNeeded() {
        guard !hasDirectResumeState else { return }
        guard !hasRestoredSession, let id = resumeRoomID else { return }
        hasRestoredSession = true
        let room = MultiplayerStore.shared.backgroundRooms.first(where: {
            $0.id == id || ($0.isStandaloneSolo && $0.serverModeSlug == serverMode.slug)
        })
        guard let room, let me = room.players.first(where: { $0.isYou }) else { return }
        startLevel = max(1, room.startLevel)
        currentQuestion = KnowledgeProblemGenerator.generate(slug: serverMode.slug, level: startLevel)
        problemCount = max(1, me.correctCount + 1)
        engine.restoreState(lives: me.lives, skips: me.skips, correctCount: me.correctCount)
    }

    private func autoSaveIfInProgress() {
        guard !engine.isRoundOver, roundResult == nil,
              engine.correctCount > 0 || engine.lives < 5 || engine.skips < 5 else { return }
        _ = MultiplayerStore.shared.saveStandaloneSoloKnowledge(
            slug: serverMode.slug,
            name: serverMode.name,
            ownUsername: username,
            lives: engine.lives,
            skips: engine.skips,
            score: 0,
            correctCount: engine.correctCount,
            startLevel: startLevel
        )
    }

    private func finaliseRound(won: Bool) {
        guard roundResult == nil else { return }
        endSessionOnce()
        roundResult = progression.applyGenericRound(
            slug: serverMode.slug,
            correctCount: engine.correctCount,
            level: startLevel,
            avgTime: avgTime,
            won: won,
            difficultyMultiplier: difficulty.scoreMultiplier
        )
    }

    private func resetRound() {
        let lvl = progression.level(forSlug: serverMode.slug)
        startLevel      = lvl
        KnowledgeProblemGenerator.resetRoundHistory(slug: serverMode.slug)
        currentQuestion = KnowledgeProblemGenerator.generate(slug: serverMode.slug, level: lvl)
        problemCount = 1; elapsedSeconds = 0; totalAnswerTime = 0
        feedbackIsCorrect = nil; selectedIndex = nil; roundResult = nil
        engine.restart()
    }

}

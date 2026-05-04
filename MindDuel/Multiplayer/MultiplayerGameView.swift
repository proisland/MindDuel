import SwiftUI

struct MultiplayerGameView: View {
    let ownUsername: String

    @ObservedObject private var store     = MultiplayerStore.shared
    @StateObject private var engine    = GameEngine()
    @ObservedObject private var progression = ProgressionStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentDigitIndex: Int   = 0
    @State private var piSessionStart:    Int   = 0  // absolute Pi digit index this session begins at
    @State private var mathProblem: MathProblem = MathProblemGenerator.generate(level: 1)
    @State private var chemProblem: ChemistryProblem = ChemistryProblemGenerator.generate(level: 1)
    @State private var geoProblem: GeographyProblem = GeographyProblemGenerator.generate(level: 1)
    @State private var elapsedSeconds: Double   = 0
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var selectedIndex: Int?      = nil
    @State private var showScoreBreakdown       = false
    @State private var breakdownPlayer: MultiplayerPlayer? = nil
    @State private var toastOpacity: Double     = 0
    @State private var showSoloQuitModal        = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            if let room = store.currentRoom {
                switch room.status {
                case .finished:
                    MultiplayerFinishedView(
                        room: room,
                        onShowBreakdown: { player in
                            breakdownPlayer = player
                            showScoreBreakdown = true
                        },
                        onLeave: {
                            store.leaveRoom()
                            dismiss()
                        }
                    )
                case .playing, .lobby:
                    gameContent(room: room)
                }
            } else {
                Color.mdBg.ignoresSafeArea()
            }

            // Event toast
            if let event = store.lastGameEvent {
                VStack {
                    Spacer()
                    Text(event.message)
                        .mdStyle(.caption)
                        .foregroundStyle(event.isPositive ? Color.mdGreen : Color.mdRed)
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.vertical, MDSpacing.xs)
                        .background(event.isPositive ? Color.mdGreenSoft : Color.mdRedSoft)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(event.isPositive ? Color.mdGreen : Color.mdRed, lineWidth: 0.5))
                        .opacity(toastOpacity)
                    Spacer().frame(height: MDSpacing.xl)
                }
                .transition(.opacity)
                .id(event.id)
            }

            if showScoreBreakdown, let player = breakdownPlayer {
                scoreBreakdownModal(player: player)
            }

            if showSoloQuitModal {
                QuitGameModal(
                    onQuit: {
                        showSoloQuitModal = false
                        store.leaveRoom()
                        dismiss()
                    },
                    onContinue: {
                        showSoloQuitModal = false
                    },
                    onSave: {
                        showSoloQuitModal = false
                        store.dismissGame()
                        dismiss()
                    }
                )
            }
        }
        .onReceive(timer) { _ in handleTimerTick() }
        .animation(.easeInOut(duration: 0.2), value: showScoreBreakdown)
        .animation(.easeInOut(duration: 0.3), value: store.currentRoom?.currentTurnIndex)
        .onChange(of: store.currentRoom?.isMyTurn) { isMyTurn in
            if isMyTurn == true {
                elapsedSeconds = 0
                feedbackIsCorrect = nil
                selectedIndex = nil
                refreshMathProblem()
            }
        }
        .onChange(of: store.lastGameEvent?.id) { _ in
            showToast()
        }
        .onAppear {
            store.cancelGameReminderNotification()
            // Resume: room.myPiDigitIndex stores the absolute digit position when saved.
            // Fresh: start at the user's current Pi level boundary, matching the
            // standalone PiGameView (#35 fix). currentDigitIndex is the in-session offset.
            let saved = store.currentRoom?.myPiDigitIndex ?? 0
            piSessionStart = saved > 0 ? saved : max(0, (ProgressionStore.shared.piLevel - 1) * 50)
            currentDigitIndex = 0
            GeographyProblemGenerator.resetRoundHistory()
            ChemistryProblemGenerator.resetRoundHistory()
            refreshMathProblem()
        }
        .onDisappear {
            store.dismissGame()
        }
    }

    private func showToast() {
        withAnimation(.easeIn(duration: 0.2)) { toastOpacity = 1 }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) { toastOpacity = 0 }
        }
    }

    // MARK: – Game content

    private func gameContent(room: MultiplayerRoom) -> some View {
        VStack(spacing: 0) {
            liveTopBar
            playerOrderStrip(room: room)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.sm)

            if room.isMyTurn {
                myTurnContent(room: room)
            } else {
                waitingContent(room: room)
            }
        }
        .overlay(alignment: .top) {
            if progression.isQuotaExhausted && room.status == .playing {
                quotaExhaustedBanner
                    .padding(.top, 60)
                    .padding(.horizontal, MDSpacing.md)
            }
        }
    }

    // MARK: – Topbar with LIVE indicator

    private var liveTopBar: some View {
        HStack(spacing: 0) {
            Button {
                guard let room = store.currentRoom else { dismiss(); return }
                if room.status == .playing && room.players.count == 1 {
                    showSoloQuitModal = true
                } else {
                    if room.status == .playing { store.dismissGame() }
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.mdText2)
            }
            .frame(width: 44, height: 44)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.mdGreen)
                    .frame(width: 7, height: 7)
                Text(String(localized: "multiplayer_live_label"))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdGreen)
            }

            Spacer()

            if let room = store.currentRoom {
                // #110: prefer the host-chosen custom name; fall back to the
                // generated room code so older saved rooms still show something.
                Text(room.customName.isEmpty
                     ? String(format: String(localized: "multiplayer_room_code_format"), room.id)
                     : room.customName)
                    .mdStyle(.micro)
                    .lineLimit(1)
                    .foregroundStyle(Color.mdAccent)
                    .padding(.horizontal, MDSpacing.xs)
                    .padding(.vertical, 4)
                    .background(Color.mdAccentSoft)
                    .clipShape(Capsule())
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, MDSpacing.md)
        .frame(height: 56)
        .background(Color.mdBg)
    }

    // MARK: – Player order strip

    private func playerOrderStrip(room: MultiplayerRoom) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MDSpacing.sm) {
                ForEach(room.players) { player in
                    playerChip(player, room: room)
                }
            }
            .padding(.vertical, MDSpacing.xs)
        }
    }

    private func playerChip(_ player: MultiplayerPlayer, room: MultiplayerRoom) -> some View {
        let isActive = room.currentPlayer?.id == player.id
        let isMine   = player.isYou
        let isMultiplayer = room.players.count > 1
        return VStack(spacing: 4) {
            ZStack {
                MDAvatar(username: player.username, size: .sm)
                    .opacity(player.isEliminated ? 0.3 : 1)
                if isActive && !player.isEliminated {
                    Circle()
                        .stroke(isMine ? Color.mdAccent : Color.mdText3, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
            if isActive && !player.isEliminated {
                Text(isMine
                     ? String(localized: "multiplayer_your_turn_label")
                     : String(localized: "multiplayer_their_turn_label"))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isMine ? Color.mdAccent : Color.mdText3)
            } else {
                Text("\(player.score) \(String(localized: "points_word"))")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(player.isEliminated ? Color.mdText3.opacity(0.4) : Color.mdText3)
            }
            if isMultiplayer {
                livesRow(for: player)
            }
        }
    }

    /// Compact "♥ N" lives indicator under each player's chip (issue #36 +
    /// design refresh: five separate hearts crowded the bar, switched to a
    /// single heart with the count).
    private func livesRow(for player: MultiplayerPlayer) -> some View {
        let remaining = max(0, min(5, player.lives))
        let dim = player.isEliminated || remaining == 0
        return HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(dim ? Color.mdRed.opacity(0.4) : Color.mdRed)
            Text("\(remaining)")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(dim ? Color.mdText3.opacity(0.4) : Color.mdText2)
        }
    }

    // MARK: – My turn

    private func myTurnContent(room: MultiplayerRoom) -> some View {
        VStack(spacing: 0) {
            ResourcePillRow(
                lives: room.players.first(where: { $0.isYou })?.lives ?? 5,
                skips: room.players.first(where: { $0.isYou })?.skips ?? 5
            )
            .padding(.horizontal, MDSpacing.md)
            .padding(.top, MDSpacing.md)

            CountdownTimer(elapsedSeconds: elapsedSeconds)
                .padding(.top, MDSpacing.sm)

            questionCard(room: room)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.lg)

            answerArea(room: room)
                .padding(.horizontal, MDSpacing.md)
                .padding(.top, MDSpacing.md)

            Spacer()

            SkipButton(elapsedSeconds: elapsedSeconds) {
                handleSkip()
            }
            .disabled(feedbackIsCorrect != nil)
            .padding(.bottom, MDSpacing.xl)
        }
    }

    // MARK: – Waiting for other player

    private func waitingContent(room: MultiplayerRoom) -> some View {
        let iAmEliminated = room.players.first(where: { $0.isYou })?.isEliminated == true
        return VStack(spacing: MDSpacing.md) {
            Spacer()

            if iAmEliminated {
                VStack(spacing: MDSpacing.sm) {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.mdRed)
                    Text(String(localized: "multiplayer_eliminated_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "multiplayer_eliminated_subtitle"))
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                    MDButton(.ghost, title: String(localized: "multiplayer_leave_action")) {
                        store.leaveRoom()
                        dismiss()
                    }
                    .padding(.horizontal, MDSpacing.lg)
                    .padding(.top, MDSpacing.xs)
                }
            } else if let current = room.currentPlayer {
                VStack(spacing: MDSpacing.sm) {
                    MDAvatar(username: current.username, size: .lg)
                    Text(String(format: String(localized: "multiplayer_waiting_for_format"),
                                current.username))
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .tint(Color.mdText3)
                    .padding(.top, MDSpacing.sm)
            }

            Spacer()
        }
        .padding(.horizontal, MDSpacing.md)
    }

    // MARK: – Question / answer

    private func questionCard(room: MultiplayerRoom) -> some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                switch room.mode {
                case .pi:
                    let absIndex = piSessionStart + currentDigitIndex
                    Text(String(format: String(localized: "pi_digits_guessed"), absIndex))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(piSequenceDisplay)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.mdText)
                        .frame(maxWidth: .infinity, alignment: .center)
                case .math:
                    Text(String(format: String(localized: "math_level_problem"),
                                room.startLevel, 1))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(MathProblemGenerator.curriculumLabel(forLevel: room.startLevel))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(mathProblem.display)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.mdText)
                        .frame(maxWidth: .infinity, alignment: .center)
                case .chemistry:
                    Text(String(format: String(localized: "chem_level_problem"),
                                room.startLevel, 1))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(ChemistryProblemGenerator.curriculumLabel(forLevel: room.startLevel))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(chemProblem.prompt)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.mdText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                case .geography:
                    Text(String(format: String(localized: "geo_level_problem"),
                                room.startLevel, 1))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(GeographyProblemGenerator.curriculumLabel(forLevel: room.startLevel))
                        .mdStyle(.micro)
                        .foregroundStyle(Color.mdText3)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if let flag = geoProblem.flag {
                        FlagView(emoji: flag, size: 72)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Text(verbatim: geoProblem.prompt)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.mdText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical, MDSpacing.sm)
        }
    }

    @ViewBuilder
    private func answerArea(room: MultiplayerRoom) -> some View {
        switch room.mode {
        case .pi:        piDigitGrid
        case .math:      mathAnswerGrid
        case .chemistry: chemAnswerGrid
        case .geography: geoAnswerGrid
        }
    }

    private var geoAnswerGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 2)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(geoProblem.options.indices, id: \.self) { i in
                AnswerButton(
                    label: geoProblem.options[i],
                    feedbackState: mathButtonState(for: i)
                ) {
                    handleGeoTap(i)
                }
                .disabled(feedbackIsCorrect != nil || progression.isQuotaExhausted)
            }
        }
    }

    private func handleGeoTap(_ index: Int) {
        guard feedbackIsCorrect == nil, !progression.isQuotaExhausted,
              let room = store.currentRoom, room.isMyTurn else { return }
        let correct = geoProblem.options[index] == geoProblem.correctAnswer
        selectedIndex = index
        feedbackIsCorrect = correct
        let time = elapsedSeconds
        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            selectedIndex = nil
            feedbackIsCorrect = nil
            elapsedSeconds = 0
            store.submitAnswer(correct: correct, answerTime: time)
        }
    }

    private var chemAnswerGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 2)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(chemProblem.options.indices, id: \.self) { i in
                AnswerButton(
                    label: chemProblem.options[i],
                    feedbackState: mathButtonState(for: i)
                ) {
                    handleChemTap(i)
                }
                .disabled(feedbackIsCorrect != nil || progression.isQuotaExhausted)
            }
        }
    }

    private func handleChemTap(_ index: Int) {
        guard feedbackIsCorrect == nil, !progression.isQuotaExhausted,
              let room = store.currentRoom, room.isMyTurn else { return }
        let correct = chemProblem.options[index] == chemProblem.correctAnswer
        selectedIndex = index
        feedbackIsCorrect = correct
        let time = elapsedSeconds
        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            selectedIndex = nil
            feedbackIsCorrect = nil
            elapsedSeconds = 0
            store.submitAnswer(correct: correct, answerTime: time)
        }
    }

    private var piDigitGrid: some View {
        let digits  = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(digits, id: \.self) { digit in
                DigitButton(digit: digit, feedbackState: piButtonState(for: digit)) {
                    handlePiTap(digit)
                }
                .disabled(feedbackIsCorrect != nil || progression.isQuotaExhausted)
            }
        }
    }

    private var mathAnswerGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: MDSpacing.sm), count: 2)
        return LazyVGrid(columns: columns, spacing: MDSpacing.sm) {
            ForEach(mathProblem.options.indices, id: \.self) { i in
                AnswerButton(
                    label: "\(mathProblem.options[i])",
                    feedbackState: mathButtonState(for: i)
                ) {
                    handleMathTap(i)
                }
                .disabled(feedbackIsCorrect != nil || progression.isQuotaExhausted)
            }
        }
    }

    // MARK: – Score breakdown modal

    private func scoreBreakdownModal(player: MultiplayerPlayer) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { showScoreBreakdown = false }
            VStack(spacing: MDSpacing.md) {
                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "score_breakdown_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText)
                    Text(String(format: String(localized: "score_breakdown_body"), player.username, player.score))
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                }
                MDButton(.ghost, title: String(localized: "continue_playing_action")) {
                    showScoreBreakdown = false
                }
            }
            .padding(MDSpacing.lg)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mdBorder2, lineWidth: 0.5))
            .padding(.horizontal, MDSpacing.lg)
        }
    }

    // MARK: – Quota banner

    private var quotaExhaustedBanner: some View {
        HStack(spacing: MDSpacing.sm) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.mdAmber)
            Text(String(localized: "quota_exhausted_message"))
                .mdStyle(.bodyMd)
            Spacer()
            MDButton(.ghost, title: String(localized: "back_to_home_action")) {
                store.dismissGame()
                dismiss()
            }
            .frame(width: 80)
        }
        .padding(MDSpacing.md)
        .background(Color.mdAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: – Pi helpers

    private var piSequenceDisplay: String {
        let absIndex = piSessionStart + currentDigitIndex
        let revealed = PiData.digits.prefix(absIndex).map { String($0) }.joined()
        if absIndex <= 10 { return "3." + revealed + "…" }
        return "…" + String(revealed.suffix(8)) + "…"
    }

    private func piButtonState(for digit: Int) -> DigitFeedbackState {
        guard let sel = selectedIndex.map({ $0 == digit ? digit : -1 }), sel == digit else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    // MARK: – Math helpers

    private func mathButtonState(for index: Int) -> AnswerFeedbackState {
        guard selectedIndex == index else { return .idle }
        switch feedbackIsCorrect {
        case true:  return .correct
        case false: return .wrong
        default:    return .idle
        }
    }

    // MARK: – Input handling

    private func handlePiTap(_ digit: Int) {
        guard feedbackIsCorrect == nil, !progression.isQuotaExhausted,
              let room = store.currentRoom, room.isMyTurn else { return }
        let target = PiData.digits[piSessionStart + currentDigitIndex]
        let correct = digit == target
        selectedIndex = digit
        feedbackIsCorrect = correct
        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                currentDigitIndex += 1
                // Save absolute digit position so resume works even if piPosition shifted.
                store.currentRoom?.myPiDigitIndex = piSessionStart + currentDigitIndex
                ProgressionStore.shared.advancePiPosition(toFrontier: piSessionStart + currentDigitIndex)
            }
            selectedIndex = nil
            feedbackIsCorrect = nil
            elapsedSeconds = 0
            store.submitAnswer(correct: correct, answerTime: elapsedSeconds)
        }
    }

    private func handleMathTap(_ index: Int) {
        guard feedbackIsCorrect == nil, !progression.isQuotaExhausted,
              let room = store.currentRoom, room.isMyTurn else { return }
        let correct = mathProblem.options[index] == mathProblem.correctAnswer
        selectedIndex = index
        feedbackIsCorrect = correct
        let time = elapsedSeconds
        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            selectedIndex = nil
            feedbackIsCorrect = nil
            elapsedSeconds = 0
            store.submitAnswer(correct: correct, answerTime: time)
        }
    }

    private func handleSkip() {
        guard let room = store.currentRoom, room.isMyTurn else { return }
        elapsedSeconds = 0
        store.useSkip()
    }

    private func handleTimerTick() {
        guard let room = store.currentRoom, room.isMyTurn,
              feedbackIsCorrect == nil, !progression.isQuotaExhausted else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 { handleSkip() }
    }

    private func refreshMathProblem() {
        guard let room = store.currentRoom else { return }
        switch room.mode {
        case .math:
            mathProblem = MathProblemGenerator.generate(level: max(1, room.startLevel))
        case .chemistry:
            chemProblem = ChemistryProblemGenerator.generate(level: max(1, room.startLevel))
        case .geography:
            geoProblem = GeographyProblemGenerator.generate(level: max(1, room.startLevel))
        case .pi:
            break
        }
    }
}

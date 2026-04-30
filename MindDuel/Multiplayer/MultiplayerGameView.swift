import SwiftUI

struct MultiplayerGameView: View {
    let ownUsername: String

    @StateObject private var store     = MultiplayerStore.shared
    @StateObject private var engine    = GameEngine()
    @Environment(\.dismiss) private var dismiss

    @State private var currentDigitIndex: Int   = 0
    @State private var mathProblem: MathProblem = MathProblemGenerator.generate(level: 1)
    @State private var elapsedSeconds: Double   = 0
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var selectedIndex: Int?      = nil
    @State private var showQuitModal            = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            if let room = store.currentRoom {
                switch room.status {
                case .finished:
                    finishedView(room: room)
                case .playing, .lobby:
                    gameContent(room: room)
                }
            } else {
                Color.mdBg.ignoresSafeArea()
            }

            if showQuitModal {
                QuitGameModal {
                    showQuitModal = false
                    store.leaveRoom()
                    dismiss()
                } onContinue: {
                    showQuitModal = false
                }
            }
        }
        .onReceive(timer) { _ in handleTimerTick() }
        .animation(.easeInOut(duration: 0.2), value: showQuitModal)
        .animation(.easeInOut(duration: 0.3), value: store.currentRoom?.currentTurnIndex)
        .onChange(of: store.currentRoom?.isMyTurn) { isMyTurn in
            if isMyTurn == true {
                elapsedSeconds = 0
                feedbackIsCorrect = nil
                selectedIndex = nil
                refreshQuestion()
            }
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
    }

    // MARK: – Topbar with LIVE indicator

    private var liveTopBar: some View {
        HStack(spacing: 0) {
            Button {
                let eliminated = store.currentRoom?.players.first(where: { $0.isYou })?.isEliminated == true
                if eliminated {
                    store.leaveRoom()
                    dismiss()
                } else {
                    showQuitModal = true
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
                Text(String(format: String(localized: "multiplayer_room_code_format"), room.id))
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
                Text("\(player.score)p")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(player.isEliminated ? Color.mdText3.opacity(0.4) : Color.mdText3)
            }
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
                if room.mode == .pi {
                    let absIndex = ProgressionStore.shared.piPosition + currentDigitIndex
                    Text(String(format: String(localized: "pi_digits_guessed"), absIndex))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(piSequenceDisplay)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.mdText)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(String(format: String(localized: "math_level_problem"),
                                room.startLevel, 1))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText2)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(mathProblem.display)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.mdText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical, MDSpacing.sm)
        }
    }

    @ViewBuilder
    private func answerArea(room: MultiplayerRoom) -> some View {
        if room.mode == .pi {
            piDigitGrid
        } else {
            mathAnswerGrid
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
                .disabled(feedbackIsCorrect != nil)
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
                .disabled(feedbackIsCorrect != nil)
            }
        }
    }

    // MARK: – Finished screen

    private func finishedView(room: MultiplayerRoom) -> some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: MDSpacing.lg) {
                Spacer()

                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mdAmber)

                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "round_over_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText2)
                    if let winner = room.winner {
                        Text(winner.isYou
                             ? String(localized: "multiplayer_you_won_label")
                             : String(format: String(localized: "multiplayer_winner_format"),
                                      winner.username))
                            .mdStyle(.title)
                            .foregroundStyle(winner.isYou ? Color.mdAccent : Color.mdText)
                    }
                }

                resultsLeaderboard(room: room)
                    .padding(.horizontal, MDSpacing.md)

                Spacer()

                VStack(spacing: MDSpacing.xs) {
                    MDButton(.primary, title: String(localized: "back_to_home_action")) {
                        store.leaveRoom()
                        dismiss()
                    }
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }

    private func resultsLeaderboard(room: MultiplayerRoom) -> some View {
        let sorted = room.players.sorted { $0.score > $1.score }
        return VStack(spacing: MDSpacing.xs) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { rank, player in
                HStack(spacing: MDSpacing.sm) {
                    Text("\(rank + 1)")
                        .mdStyle(.bodyMd)
                        .foregroundStyle(rank == 0 ? Color.mdAmber : Color.mdText3)
                        .frame(width: 20, alignment: .center)
                    MDAvatar(username: player.username, size: .sm)
                    Text("@\(player.username)")
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText)
                    if player.isYou {
                        MDPillTag(label: String(localized: "your_label"), variant: .accent)
                    }
                    Spacer()
                    Text("\(player.score)p")
                        .mdStyle(.bodyMd)
                        .foregroundStyle(rank == 0 ? Color.mdAmber : Color.mdText2)
                }
                .padding(.horizontal, MDSpacing.md)
                .padding(.vertical, MDSpacing.sm)
                .background(player.isYou ? Color.mdAccentSoft : (rank == 0 ? Color.mdAmberSoft : Color.mdSurface2))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
            }
        }
    }

    // MARK: – Pi helpers

    private var piSequenceDisplay: String {
        let absIndex = ProgressionStore.shared.piPosition + currentDigitIndex
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
        guard feedbackIsCorrect == nil, let room = store.currentRoom, room.isMyTurn else { return }
        let target = PiData.digits[ProgressionStore.shared.piPosition + currentDigitIndex]
        let correct = digit == target
        selectedIndex = digit
        feedbackIsCorrect = correct
        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct { currentDigitIndex += 1 }
            selectedIndex = nil
            feedbackIsCorrect = nil
            elapsedSeconds = 0
            store.submitAnswer(correct: correct, answerTime: elapsedSeconds)
        }
    }

    private func handleMathTap(_ index: Int) {
        guard feedbackIsCorrect == nil, let room = store.currentRoom, room.isMyTurn else { return }
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
        guard let room = store.currentRoom, room.isMyTurn, feedbackIsCorrect == nil else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 { handleSkip() }
    }

    private func refreshQuestion() {
        guard let room = store.currentRoom else { return }
        if room.mode == .math {
            mathProblem = MathProblemGenerator.generate(level: max(1, room.startLevel))
        }
    }
}

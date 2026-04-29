import SwiftUI

struct MathGameView: View {
    let username: String
    @StateObject private var engine = GameEngine()
    @State private var problem = MathProblemGenerator.generate()
    @State private var problemCount = 1
    @State private var elapsedSeconds: Double = 0
    @State private var selectedIndex: Int? = nil
    @State private var feedbackIsCorrect: Bool? = nil
    @State private var showQuitModal = false

    @Environment(\.dismiss) private var dismiss

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            if engine.isRoundOver {
                RoundEndView(correctCount: engine.correctCount) {
                    engine.restart()
                    problem = MathProblemGenerator.generate()
                    problemCount = 1
                    elapsedSeconds = 0
                    feedbackIsCorrect = nil
                    selectedIndex = nil
                } onHome: {
                    dismiss()
                }
            } else {
                gameContent
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

            SkipButton(elapsedSeconds: elapsedSeconds, onSkip: handleSkip)
                .disabled(isInteractionBlocked)
                .padding(.top, MDSpacing.lg)

            Spacer()
        }
        .overlay {
            if engine.isWaitingAfterSkip {
                waitingOverlay
            }
        }
    }

    private var problemCard: some View {
        MDPrimaryCard {
            VStack(spacing: MDSpacing.xs) {
                Text(String(format: String(localized: "math_level_problem"), 1, problemCount))
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
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip, feedbackIsCorrect == nil else { return }
        selectedIndex = index
        let correct = problem.options[index] == problem.correctAnswer
        feedbackIsCorrect = correct

        Task {
            try? await Task.sleep(nanoseconds: correct ? 250_000_000 : 300_000_000)
            if correct {
                engine.recordCorrect()
            } else {
                engine.recordWrong()
            }
            guard !engine.isRoundOver else {
                selectedIndex = nil
                feedbackIsCorrect = nil
                return
            }
            nextProblem()
            selectedIndex = nil
            feedbackIsCorrect = nil
        }
    }

    private func handleSkip() {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip else { return }
        elapsedSeconds = 0
        engine.useSkip()
    }

    private func handleTimerTick() {
        guard !engine.isRoundOver, !engine.isWaitingAfterSkip, feedbackIsCorrect == nil else { return }
        elapsedSeconds = min(elapsedSeconds + 0.1, 10.0)
        if elapsedSeconds >= 10.0 {
            handleSkip()
        }
    }

    private func nextProblem() {
        problem = MathProblemGenerator.generate()
        problemCount += 1
        elapsedSeconds = 0
    }
}

enum AnswerFeedbackState: Equatable {
    case idle, correct, wrong
}

private struct AnswerButton: View {
    let label: String
    let feedbackState: AnswerFeedbackState
    let action: () -> Void

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

    private var textColor: Color {
        switch feedbackState {
        case .idle:    return .mdText
        case .correct: return .mdGreen
        case .wrong:   return .mdRed
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
        }
        .animation(.easeInOut(duration: 0.15), value: feedbackState)
    }
}

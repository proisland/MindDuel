import SwiftUI

/// #96: shows a recap of the round's answers — every player vs every
/// question with a check or cross — so everybody can compare results
/// before the next round starts. Tap "Continue" to dismiss and resume.
struct MultiplayerRoundSummaryView: View {
    let summary: MultiplayerStore.RoundSummary
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: 0) {
                MDTopBar(title: String(format: String(localized: "round_summary_title_format"),
                                       summary.roundIndex),
                         leadingAction: { dismiss(); onContinue() }) { EmptyView() }

                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        ForEach(Array(summary.problems.enumerated()), id: \.offset) { idx, problem in
                            problemCard(idx: idx, problem: problem)
                        }
                        MDButton(.primary, title: String(localized: "round_summary_continue_action")) {
                            dismiss()
                            onContinue()
                        }
                        .padding(.top, MDSpacing.sm)
                    }
                    .padding(MDSpacing.md)
                }
            }
        }
    }

    private func problemCard(idx: Int, problem: SharedProblem) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: String(localized: "round_summary_question_format"), idx + 1))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdText3)
                Spacer()
                Text(String(format: String(localized: "round_summary_correct_answer_format"),
                            problem.options[problem.correctIndex]))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdGreen)
            }

            // #120: render flags via FlagView so the actual PNG loads —
            // the inline emoji path renders as "?" on iOS Simulator and on
            // some devices where the regional-indicator glyphs are missing.
            if let flag = problem.flag {
                FlagView(emoji: flag, size: 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(problem.prompt)
                .mdStyle(.bodyMd)
                .foregroundStyle(Color.mdText)

            Divider().background(Color.mdBorder2)

            VStack(spacing: MDSpacing.xs) {
                ForEach(summary.players) { player in
                    answerRow(idx: idx, player: player)
                }
            }
        }
        .padding(MDSpacing.md)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    private func answerRow(idx: Int, player: MultiplayerPlayer) -> some View {
        let answer = summary.answers.first { $0.playerID == player.id && $0.questionInRound == idx }
        return HStack(spacing: MDSpacing.sm) {
            MDAvatar(username: player.username, size: .sm)
            Text(player.username)
                .mdStyle(.caption)
                .foregroundStyle(Color.mdText)
            if player.isYou {
                MDPillTag(label: String(localized: "your_label"), variant: .accent)
            }
            Spacer()
            if let a = answer {
                if a.skipped {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mdAmber)
                } else if a.correct {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.mdGreen)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.mdRed)
                }
            } else {
                Text("–").mdStyle(.caption).foregroundStyle(Color.mdText3)
            }
        }
    }
}

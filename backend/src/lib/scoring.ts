const K = 100 // calibration constant — adjustable via admin in future

interface Answer {
  isCorrect: boolean
  answerTimeMs: number
  difficulty: number // 1 for Pi digits; level (1–20) for knowledge modes
  wasSkipped: boolean
}

export function calculateScore(answers: Answer[]): number {
  const scored = answers.filter(a => a.isCorrect && !a.wasSkipped)
  if (scored.length === 0) return 0

  const avgTimeSeconds =
    scored.reduce((sum, a) => sum + a.answerTimeMs, 0) / scored.length / 1000

  if (avgTimeSeconds <= 0) return 0

  const totalDifficulty = scored.reduce((sum, a) => sum + a.difficulty, 0)
  return Math.round(totalDifficulty * (K / avgTimeSeconds))
}

export function applyProgressionDelta(
  position: number,
  correctCount: number,
  isWin: boolean,
  rollbackPercent: number = 0.15,
  minPosition: number = 0,
): number {
  if (isWin) {
    return position + correctCount
  }
  const rollback = Math.round(correctCount * rollbackPercent)
  return Math.max(minPosition, position - rollback)
}

export function shouldFlagUser(fastRoundCount: number, threshold = 5): boolean {
  return fastRoundCount >= threshold
}

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
  minPosition: number = 0,
): number {
  // Position maps 1:1 to level number. +1 per win, -1 per loss (floor 0).
  if (isWin) return position + 1
  if (correctCount === 0) return position          // no answers → no rollback
  return Math.max(minPosition, position - 1)
}

export function shouldFlagUser(fastRoundCount: number, threshold = 5): boolean {
  return fastRoundCount >= threshold
}

import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { validatePiAnswer } from '../../lib/pi'
import { calculateScore, applyProgressionDelta, shouldFlagUser } from '../../lib/scoring'
import { config } from '../../config'

const MIN_ANSWER_MS = 200
const FAST_AVG_THRESHOLD_MS = 400
const FAST_ROUND_MIN_ANSWERS = 5
const FLAG_THRESHOLD = 5

const startSessionBody = z.object({
  mode: z.string().min(1),
  isTraining: z.boolean().default(false),
  localDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  startPosition: z.number().int().min(0).optional(),
})

const submitAnswerBody = z.object({
  questionRef: z.string().min(1),
  userAnswer: z.string().min(0),
  answerTimeMs: z.number().int().positive(),
  waitTimeMs: z.number().int().min(0).default(0),
  wasSkipped: z.boolean().default(false),
  // Client-supplied correctness for procedurally-generated knowledge questions.
  // Pi always validates server-side via the digit position; knowledge modes
  // currently generate questions on-device with no QuestionPack-matching id,
  // so we trust the client's verdict (anti-cheat is enforced via timing).
  isCorrect: z.boolean().optional(),
})

const endSessionBody = z.object({
  reason: z.enum(['no_lives', 'no_skips', 'user_quit', 'won']),
})

const syncQuotaBody = z.object({
  localDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  localCount: z.number().int().min(0).max(config.quota.freeLimit),
})

async function getOrCreateQuota(
  prisma: FastifyInstance['prisma'],
  userId: string,
  localDate: string,
) {
  return prisma.dailyQuota.upsert({
    where: { userId },
    update: {},
    create: { userId, date: localDate, count: 0 },
  })
}

async function checkQuota(
  prisma: FastifyInstance['prisma'],
  userId: string,
  isPremium: boolean,
  isTraining: boolean,
  localDate: string,
): Promise<{ allowed: boolean; count: number; remaining: number }> {
  if (isPremium || isTraining) return { allowed: true, count: 0, remaining: 999 }

  const quota = await getOrCreateQuota(prisma, userId, localDate)
  const count = quota.date === localDate ? quota.count : 0
  const remaining = Math.max(0, config.quota.freeLimit - count)
  return { allowed: remaining > 0, count, remaining }
}

export default async function gamesRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // POST /v1/games/sessions — start a session
  app.post('/sessions', auth, async (request, reply) => {
    const body = startSessionBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body', details: body.error.flatten() })

    const now = new Date()
    const activeMode = await app.prisma.gameMode.findFirst({
      where: {
        slug: body.data.mode,
        isActive: true,
        OR: [{ startsAt: null }, { startsAt: { lte: now } }],
        AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
      },
      select: { id: true },
    })
    if (!activeMode) return reply.status(400).send({ error: 'Mode not available' })

    const user = await app.prisma.user.findUnique({
      where: { id: request.userId },
      select: { isPremium: true, isSuspended: true, progressions: { where: { mode: body.data.mode } } },
    })
    if (!user) return reply.status(404).send({ error: 'User not found' })
    if (user.isSuspended) return reply.status(403).send({ error: 'Account suspended' })

    const { allowed, remaining } = await checkQuota(
      app.prisma, request.userId, user.isPremium, body.data.isTraining, body.data.localDate,
    )
    if (!allowed) return reply.status(429).send({ error: 'Daily quota exceeded', quotaRemaining: 0 })

    const progression = user.progressions[0]
    const startPos = body.data.startPosition ?? progression?.position ?? 0

    const session = await app.prisma.$transaction(async (tx) => {
      const s = await tx.gameSession.create({
        data: {
          userId: request.userId,
          mode: body.data.mode,
          isTraining: body.data.isTraining,
        },
      })
      await tx.$executeRaw`UPDATE "GameSession" SET "startPosition" = ${startPos} WHERE id = ${s.id}`
      return s
    })

    return reply.send({
      sessionToken: session.sessionToken,
      mode: session.mode,
      isTraining: session.isTraining,
      startPosition: startPos,
      quotaRemaining: remaining,
    })
  })

  // POST /v1/games/sessions/:token/answers — submit one answer
  app.post('/sessions/:token/answers', auth, async (request, reply) => {
    const { token } = request.params as { token: string }
    const body = submitAnswerBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body', details: body.error.flatten() })

    if (!body.data.wasSkipped && body.data.answerTimeMs < MIN_ANSWER_MS) {
      return reply.status(400).send({ error: `Answer time below minimum (${MIN_ANSWER_MS}ms)` })
    }

    const session = await app.prisma.gameSession.findUnique({
      where: { sessionToken: token },
      select: { id: true, userId: true, mode: true, isTraining: true, endedAt: true },
    })
    if (!session) return reply.status(404).send({ error: 'Session not found' })
    if (session.userId !== request.userId) return reply.status(403).send({ error: 'Forbidden' })
    if (session.endedAt) return reply.status(409).send({ error: 'Session already ended' })

    // Validate answer serverside
    let isCorrect = false
    let correctAnswer = ''

    if (session.mode === 'pi') {
      const position = parseInt(body.data.questionRef, 10)
      isCorrect = !body.data.wasSkipped && validatePiAnswer(position, body.data.userAnswer)
      const { getPiDigit } = await import('../../lib/pi')
      correctAnswer = getPiDigit(position)
    } else if (body.data.isCorrect !== undefined) {
      // Procedural knowledge mode: trust the client's verdict.
      isCorrect = !body.data.wasSkipped && body.data.isCorrect
      correctAnswer = body.data.userAnswer
    } else {
      // Fallback: look up question in QuestionPack (server-validated knowledge).
      const pack = await app.prisma.questionPack.findFirst({
        where: { mode: session.mode, isActive: true },
        orderBy: { version: 'desc' },
      })
      if (pack) {
        const questions = pack.data as Array<{ id: string; answer: string }>
        const q = questions.find(q => q.id === body.data.questionRef)
        if (q) {
          correctAnswer = q.answer
          isCorrect = !body.data.wasSkipped && q.answer === body.data.userAnswer
        }
      }
    }

    // Persist answer
    const difficulty = session.mode === 'pi' ? 1 : 1 // level-based difficulty set at session end
    await app.prisma.gameAnswer.create({
      data: {
        sessionId: session.id,
        questionRef: body.data.questionRef,
        userAnswer: body.data.wasSkipped ? '__skip__' : body.data.userAnswer,
        isCorrect,
        answerTimeMs: body.data.answerTimeMs,
        waitTimeMs: body.data.waitTimeMs,
      },
    })

    // Update quota (non-training only)
    let quotaRemaining = 999
    if (!session.isTraining) {
      const user = await app.prisma.user.findUnique({
        where: { id: request.userId },
        select: { isPremium: true },
      })
      if (!user?.isPremium) {
        const today = new Date().toISOString().slice(0, 10)
        // Use $executeRaw to atomically reset-or-increment in a single statement:
        // - same day → increment
        // - new day  → reset to 1 (don't carry over yesterday's count)
        await app.prisma.$executeRaw`
          INSERT INTO "DailyQuota" ("userId", "date", "count", "updatedAt")
          VALUES (${request.userId}, ${today}, 1, NOW())
          ON CONFLICT ("userId") DO UPDATE
            SET "count"     = CASE WHEN "DailyQuota"."date" = ${today} THEN "DailyQuota"."count" + 1 ELSE 1 END,
                "date"      = ${today},
                "updatedAt" = NOW()
        `
        const quota = await app.prisma.dailyQuota.findUniqueOrThrow({ where: { userId: request.userId } })
        quotaRemaining = Math.max(0, config.quota.freeLimit - quota.count)
      }
    }

    return reply.send({ isCorrect, correctAnswer, quotaRemaining })
  })

  // POST /v1/games/sessions/:token/end — finalise session
  app.post('/sessions/:token/end', auth, async (request, reply) => {
    const { token } = request.params as { token: string }
    const body = endSessionBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const session = await app.prisma.gameSession.findUnique({
      where: { sessionToken: token },
      include: { answers: true },
    })
    if (!session) return reply.status(404).send({ error: 'Session not found' })
    if (session.userId !== request.userId) return reply.status(403).send({ error: 'Forbidden' })
    if (session.endedAt) return reply.status(409).send({ error: 'Session already ended' })

    const isWin = body.data.reason === 'won'
    const correctAnswers = session.answers.filter(a => a.isCorrect)
    const correctCount = correctAnswers.length

    const scoredAnswers = session.answers.map(a => ({
      isCorrect: a.isCorrect,
      answerTimeMs: a.answerTimeMs,
      difficulty: 1,
      wasSkipped: a.userAnswer === '__skip__',
    }))
    const score = session.isTraining ? 0 : calculateScore(scoredAnswers)

    const { updatedProgression, quota } = await app.prisma.$transaction(async (tx) => {
      // Anti-cheat: check average response time
      if (!session.isTraining && correctAnswers.length >= FAST_ROUND_MIN_ANSWERS) {
        const avgMs = correctAnswers.reduce((s, a) => s + a.answerTimeMs, 0) / correctAnswers.length
        if (avgMs < FAST_AVG_THRESHOLD_MS) {
          const user = await tx.user.findUnique({
            where: { id: request.userId },
            select: { fastRoundCount: true },
          })
          const newCount = (user?.fastRoundCount ?? 0) + 1
          await tx.user.update({
            where: { id: request.userId },
            data: {
              fastRoundCount: newCount,
              ...(shouldFlagUser(newCount, FLAG_THRESHOLD) && { isFlagged: true }),
            },
          })
        }
      }

      // Update progression (upsert to ensure row exists, then apply delta)
      const progression = await tx.progression.upsert({
        where: { userId_mode: { userId: request.userId, mode: session.mode } },
        update: {},
        create: { userId: request.userId, mode: session.mode, position: 0 },
      })

      const newPosition = session.isTraining
        ? progression.position
        : applyProgressionDelta(progression.position, correctCount, isWin)

      // Compute daily streak (training sessions don't count toward streak)
      const today     = new Date().toISOString().slice(0, 10)
      const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10)
      const lastDate  = progression.lastPlayedDate

      let newStreak = progression.currentStreak
      if (!session.isTraining) {
        if (lastDate === yesterday) newStreak = progression.currentStreak + 1
        else if (lastDate === today) newStreak = progression.currentStreak // same day, no change
        else newStreak = 1 // streak broken or first time
      }
      const newLongest = Math.max(progression.longestStreak, newStreak)

      const updatedProgression = await tx.progression.update({
        where: { userId_mode: { userId: request.userId, mode: session.mode } },
        data: {
          position: newPosition,
          ...(session.isTraining ? {} : {
            currentStreak:  newStreak,
            longestStreak:  newLongest,
            lastPlayedDate: today,
          }),
        },
      })

      if (!session.isTraining && score > 0) {
        await tx.score.create({
          data: { userId: request.userId, mode: session.mode, value: score },
        })
      }

      await tx.gameSession.update({
        where: { id: session.id },
        data: {
          endedAt: new Date(),
          score,
          correctCount,
          totalCount: session.answers.length,
        },
      })

      await tx.user.update({
        where: { id: request.userId },
        data: {
          totalRoundsPlayed: { increment: 1 },
          totalCorrectAnswers: { increment: correctCount },
          lastActiveAt: new Date(),
        },
      })

      const quota = await tx.dailyQuota.findUnique({ where: { userId: request.userId } })

      return { updatedProgression, quota }
    })

    return reply.send({
      score,
      progression: {
        mode:           updatedProgression.mode,
        position:       updatedProgression.position,
        progress:       updatedProgression.progress,
        currentStreak:  updatedProgression.currentStreak,
        longestStreak:  updatedProgression.longestStreak,
      },
      quota: quota ? { date: quota.date, count: quota.count } : null,
    })
  })

  // GET /v1/games/quota
  app.get('/quota', auth, async (request, reply) => {
    const { localDate } = request.query as { localDate?: string }
    const date = localDate ?? new Date().toISOString().slice(0, 10)

    const [user, quota] = await Promise.all([
      app.prisma.user.findUnique({ where: { id: request.userId }, select: { isPremium: true } }),
      app.prisma.dailyQuota.findUnique({ where: { userId: request.userId } }),
    ])

    if (!user) return reply.status(404).send({ error: 'User not found' })

    const count = quota?.date === date ? quota.count : 0
    const limit = config.quota.freeLimit
    const remaining = user.isPremium ? 999 : Math.max(0, limit - count)

    return reply.send({ date, count, limit: user.isPremium ? null : limit, remaining })
  })

  // POST /v1/games/quota/sync — reconcile offline count with server
  app.post('/quota/sync', auth, async (request, reply) => {
    const body = syncQuotaBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const { localDate, localCount } = body.data

    const existing = await app.prisma.dailyQuota.findUnique({ where: { userId: request.userId } })
    // Same day: take max(server, local) to reconcile offline play.
    // New day (from iOS perspective): trust localCount as the fresh day's tally.
    const syncedCount = existing?.date === localDate
      ? Math.max(existing.count, localCount)
      : localCount

    await app.prisma.$executeRaw`
      INSERT INTO "DailyQuota" ("userId", "date", "count", "updatedAt")
      VALUES (${request.userId}, ${localDate}, ${syncedCount}, NOW())
      ON CONFLICT ("userId") DO UPDATE
        SET "count"     = ${syncedCount},
            "date"      = ${localDate},
            "updatedAt" = NOW()
    `

    const user = await app.prisma.user.findUnique({ where: { id: request.userId }, select: { isPremium: true, isUnlimited: true } })
    const limit = (user?.isPremium || user?.isUnlimited) ? 9999 : config.quota.freeLimit
    return reply.send({ used: syncedCount, limit })
  })
}

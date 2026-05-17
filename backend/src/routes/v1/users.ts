import type { FastifyInstance } from 'fastify'

export default async function usersRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/users/search?q=... — search by username prefix
  app.get('/search', auth, async (request, reply) => {
    const { q } = request.query as { q?: string }
    if (!q || q.length < 2) return reply.send([])

    const users = await app.prisma.user.findMany({
      where: {
        username: { contains: q, mode: 'insensitive' },
        isSuspended: false,
      },
      select: { id: true, username: true, avatarEmoji: true, isPremium: true },
      take: 20,
    })

    return reply.send(users)
  })

  // GET /v1/users/:username — public profile
  app.get('/:username', auth, async (request, reply) => {
    const { username } = request.params as { username: string }

    const user = await app.prisma.user.findUnique({
      where: { username },
      select: {
        id: true,
        username: true,
        avatarEmoji: true,
        isPremium: true,
        isFlagged: true,
        lastActiveAt: true,
        createdAt: true,
        totalRoundsPlayed: true,
        totalCorrectAnswers: true,
        totalCorrectAnswerTimeMs: true,
        progressions: {
          select: { mode: true, position: true, progress: true },
        },
      },
    })

    if (!user) return reply.status(404).send({ error: 'User not found' })

    const avgAnswerTimeMs = user.totalCorrectAnswers > 0
      ? Number(user.totalCorrectAnswerTimeMs) / user.totalCorrectAnswers
      : 0

    return reply.send({
      id: user.id,
      username: user.username,
      avatarEmoji: user.avatarEmoji,
      isPremium: user.isPremium,
      isFlagged: user.isFlagged,
      lastActiveAt: user.lastActiveAt,
      memberSince: user.createdAt,
      roundsPlayed: user.totalRoundsPlayed,
      avgAnswerTimeMs,
      progressions: user.progressions,
    })
  })
}

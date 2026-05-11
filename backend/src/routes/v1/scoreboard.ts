import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const scoreboardQuery = z.object({
  mode: z.string().min(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
})

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000

export default async function scoreboardRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/scoreboard/global?mode=pi&limit=100
  app.get('/global', auth, async (request, reply) => {
    const query = scoreboardQuery.safeParse(request.query)
    if (!query.success) return reply.status(400).send({ error: 'Invalid query', details: query.error.flatten() })

    const since = new Date(Date.now() - THIRTY_DAYS_MS)

    const rows = await app.prisma.score.groupBy({
      by: ['userId'],
      where: {
        mode: query.data.mode,
        createdAt: { gte: since },
        user: { isFlagged: false, isSuspended: false },
      },
      _avg: { value: true },
      _count: { value: true },
      orderBy: { _avg: { value: 'desc' } },
      take: query.data.limit,
    })

    const userIds = rows.map(r => r.userId)
    const users = await app.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, username: true, avatarEmoji: true, birthDate: true },
    })
    const userMap = new Map(users.map(u => [u.id, u]))

    const entries = rows.map((row, i) => {
      const u = userMap.get(row.userId)
      const age = u?.birthDate
        ? Math.floor((Date.now() - u.birthDate.getTime()) / (1000 * 60 * 60 * 24 * 365.25))
        : null
      return {
        rank: i + 1,
        userId: row.userId,
        username: u?.username ?? '?',
        avatarEmoji: u?.avatarEmoji ?? '🧠',
        age,
        avgScore: Math.round(row._avg.value ?? 0),
        roundCount: row._count.value,
        isMe: row.userId === request.userId,
      }
    })

    return reply.send({ mode: query.data.mode, entries })
  })

  // GET /v1/scoreboard/friends?mode=pi
  app.get('/friends', auth, async (request, reply) => {
    const query = scoreboardQuery.safeParse(request.query)
    if (!query.success) return reply.status(400).send({ error: 'Invalid query' })

    const since = new Date(Date.now() - THIRTY_DAYS_MS)

    // Find friend IDs
    const friendships = await app.prisma.friendship.findMany({
      where: {
        OR: [{ senderId: request.userId }, { receiverId: request.userId }],
      },
      select: { senderId: true, receiverId: true },
    })
    const friendIds = friendships.map(f =>
      f.senderId === request.userId ? f.receiverId : f.senderId,
    )
    const allIds = [request.userId, ...friendIds]

    const rows = await app.prisma.score.groupBy({
      by: ['userId'],
      where: { mode: query.data.mode, userId: { in: allIds }, createdAt: { gte: since } },
      _avg: { value: true },
      _count: { value: true },
      orderBy: { _avg: { value: 'desc' } },
    })

    const users = await app.prisma.user.findMany({
      where: { id: { in: rows.map(r => r.userId) } },
      select: { id: true, username: true, avatarEmoji: true, birthDate: true },
    })
    const userMap = new Map(users.map(u => [u.id, u]))

    const entries = rows.map((row, i) => {
      const u = userMap.get(row.userId)
      const age = u?.birthDate
        ? Math.floor((Date.now() - u.birthDate.getTime()) / (1000 * 60 * 60 * 24 * 365.25))
        : null
      return {
        rank: i + 1,
        userId: row.userId,
        username: u?.username ?? '?',
        avatarEmoji: u?.avatarEmoji ?? '🧠',
        age,
        avgScore: Math.round(row._avg.value ?? 0),
        roundCount: row._count.value,
        isMe: row.userId === request.userId,
      }
    })

    return reply.send({ mode: query.data.mode, entries })
  })

  // GET /v1/users/:username/profile — public profile
  app.get('/users/:username', auth, async (request, reply) => {
    const { username } = request.params as { username: string }

    const user = await app.prisma.user.findUnique({
      where: { username },
      select: {
        id: true,
        username: true,
        avatarEmoji: true,
        birthDate: true,
        isFlagged: true,
        isSuspended: true,
        totalRoundsPlayed: true,
        lastActiveAt: true,
        createdAt: true,
        progressions: true,
      },
    })
    if (!user) return reply.status(404).send({ error: 'User not found' })

    const isFriend = await app.prisma.friendship.findFirst({
      where: {
        OR: [
          { senderId: request.userId, receiverId: user.id },
          { senderId: user.id, receiverId: request.userId },
        ],
      },
    })

    const hasPendingRequest = !isFriend
      ? await app.prisma.friendRequest.findFirst({
          where: {
            OR: [
              { fromUserId: request.userId, toUserId: user.id },
              { fromUserId: user.id, toUserId: request.userId },
            ],
          },
        })
      : null

    const age = user.birthDate
      ? Math.floor((Date.now() - user.birthDate.getTime()) / (1000 * 60 * 60 * 24 * 365.25))
      : null

    return reply.send({
      id: user.id,
      username: user.username,
      avatarEmoji: user.avatarEmoji,
      age,
      isFlagged: user.isFlagged,
      isSuspended: user.isSuspended,
      totalRoundsPlayed: user.totalRoundsPlayed,
      lastActiveAt: user.lastActiveAt?.toISOString() ?? null,
      createdAt: user.createdAt.toISOString(),
      progressions: user.progressions.map(p => ({ mode: p.mode, position: p.position, progress: p.progress })),
      social: {
        isFriend: !!isFriend,
        hasPendingRequest: !!hasPendingRequest,
      },
    })
  })

  // GET /v1/users/search?q=username
  app.get('/users', auth, async (request, reply) => {
    const { q } = request.query as { q?: string }
    if (!q || q.length < 2) return reply.status(400).send({ error: 'Query too short' })

    const users = await app.prisma.user.findMany({
      where: {
        username: { contains: q, mode: 'insensitive' },
        isSuspended: false,
        NOT: { id: request.userId },
      },
      take: 20,
      select: { id: true, username: true, avatarEmoji: true },
    })

    return reply.send({ users })
  })
}

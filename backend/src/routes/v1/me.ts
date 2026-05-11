import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const RESERVED_USERNAMES = new Set(['admin', 'mindduel', 'support', 'moderator', 'system'])
const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/

const patchBody = z.object({
  username: z.string().regex(USERNAME_RE).optional(),
  avatarEmoji: z.string().emoji().optional(),
  birthDate: z.string().datetime().optional(),
})

const usernameBody = z.object({
  username: z.string().regex(USERNAME_RE),
})

const pushTokenBody = z.object({
  deviceToken: z.string().min(1),
})

export default async function meRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/me
  app.get('/', auth, async (request, reply) => {
    const user = await app.prisma.user.findUnique({
      where: { id: request.userId },
      include: {
        progressions: true,
        dailyQuota: true,
      },
    })

    if (!user) return reply.status(404).send({ error: 'User not found' })

    return reply.send({
      id: user.id,
      username: user.username,
      avatarEmoji: user.avatarEmoji,
      birthDate: user.birthDate?.toISOString() ?? null,
      isPremium: user.isPremium,
      isFlagged: user.isFlagged,
      isSuspended: user.isSuspended,
      totalRoundsPlayed: user.totalRoundsPlayed,
      totalCorrectAnswers: user.totalCorrectAnswers,
      lastActiveAt: user.lastActiveAt?.toISOString() ?? null,
      createdAt: user.createdAt.toISOString(),
      progressions: user.progressions.map(p => ({
        mode: p.mode,
        position: p.position,
        progress: p.progress,
      })),
      dailyQuota: user.dailyQuota
        ? { date: user.dailyQuota.date, count: user.dailyQuota.count }
        : { date: null, count: 0 },
    })
  })

  // POST /v1/me/username — set username (only if not yet set)
  app.post('/username', auth, async (request, reply) => {
    const body = usernameBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid username', details: body.error.flatten() })
    }

    const { username } = body.data

    if (RESERVED_USERNAMES.has(username.toLowerCase())) {
      return reply.status(409).send({ error: 'Username is reserved' })
    }

    const current = await app.prisma.user.findUnique({
      where: { id: request.userId },
      select: { username: true },
    })

    if (current?.username) {
      return reply.status(409).send({ error: 'Username already set' })
    }

    const taken = await app.prisma.user.findUnique({ where: { username } })
    if (taken) {
      return reply.status(409).send({ error: 'Username taken' })
    }

    const user = await app.prisma.user.update({
      where: { id: request.userId },
      data: { username },
    })

    return reply.send({ username: user.username })
  })

  // PATCH /v1/me
  app.patch('/', auth, async (request, reply) => {
    const body = patchBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid body', details: body.error.flatten() })
    }

    const { username, avatarEmoji, birthDate } = body.data

    if (username) {
      if (RESERVED_USERNAMES.has(username.toLowerCase())) {
        return reply.status(409).send({ error: 'Username is reserved' })
      }
      const taken = await app.prisma.user.findFirst({
        where: { username, NOT: { id: request.userId } },
      })
      if (taken) return reply.status(409).send({ error: 'Username taken' })
    }

    const user = await app.prisma.user.update({
      where: { id: request.userId },
      data: {
        ...(username && { username }),
        ...(avatarEmoji && { avatarEmoji }),
        ...(birthDate && { birthDate: new Date(birthDate) }),
      },
    })

    return reply.send({ id: user.id, username: user.username, avatarEmoji: user.avatarEmoji })
  })

  // POST /v1/me/push-token
  app.post('/push-token', auth, async (request, reply) => {
    const body = pushTokenBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid body' })
    }

    await app.prisma.pushToken.upsert({
      where: { deviceToken: body.data.deviceToken },
      update: { userId: request.userId },
      create: { userId: request.userId, deviceToken: body.data.deviceToken },
    })

    return reply.status(204).send()
  })

  // DELETE /v1/me
  app.delete('/', auth, async (request, reply) => {
    await app.prisma.user.delete({ where: { id: request.userId } })
    return reply.status(204).send()
  })
}

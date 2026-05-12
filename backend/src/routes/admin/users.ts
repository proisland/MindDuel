import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const patchBody = z.object({
  isFlagged:   z.boolean().optional(),
  isSuspended: z.boolean().optional(),
  flagReason:  z.string().optional(),
})

export default async function adminUsersRoutes(app: FastifyInstance) {
  // GET /admin/users
  app.get('/', async (request, reply) => {
    const { q, flagged, suspended, page } = request.query as Record<string, string>
    const take = 50
    const skip = (parseInt(page ?? '1', 10) - 1) * take

    const where: any = {
      ...(q && { username: { contains: q, mode: 'insensitive' } }),
      ...(flagged === 'true' && { isFlagged: true }),
      ...(suspended === 'true' && { isSuspended: true }),
    }

    const [users, total] = await Promise.all([
      app.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        select: {
          id: true, username: true, avatarEmoji: true, isPremium: true,
          isFlagged: true, isSuspended: true, fastRoundCount: true,
          totalRoundsPlayed: true, lastActiveAt: true, createdAt: true,
        },
      }),
      app.prisma.user.count({ where }),
    ])

    return reply.view('admin/users.ejs', {
      title: 'Users', users, total,
      page: parseInt(page ?? '1', 10), take,
      q: q ?? '', flagged: flagged === 'true', suspended: suspended === 'true',
    })
  })

  // GET /admin/users/:id
  app.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const [user, modeStats] = await Promise.all([
      app.prisma.user.findUnique({
        where: { id },
        include: {
          progressions: true,
          scores:       { orderBy: { createdAt: 'desc' }, take: 20 },
          feedbacks:    { orderBy: { createdAt: 'desc' }, take: 10 },
          gameSessions: { orderBy: { startedAt: 'desc' }, take: 20 },
        },
      }),
      app.prisma.gameSession.groupBy({
        by: ['mode'],
        where: { userId: id },
        _count: { id: true },
        _sum:   { correctCount: true, totalCount: true },
        orderBy: { mode: 'asc' },
      }),
    ])
    if (!user) return reply.status(404).send('Not found')

    const modeStatsFormatted = modeStats.map(s => ({
      mode:         s.mode,
      rounds:       s._count.id,
      answered:     s._sum.totalCount ?? 0,
      correct:      s._sum.correctCount ?? 0,
      pctCorrect:   s._sum.totalCount ? Math.round((s._sum.correctCount ?? 0) / s._sum.totalCount * 100) : null,
    }))

    return reply.view('admin/user-detail.ejs', { title: `@${user.username}`, user, modeStats: modeStatsFormatted })
  })

  // PATCH /admin/users/:id (JSON API for HTMX)
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = patchBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const user = await app.prisma.user.update({
      where: { id },
      data: body.data,
    })
    return reply.send({ ok: true, isFlagged: user.isFlagged, isSuspended: user.isSuspended })
  })
}

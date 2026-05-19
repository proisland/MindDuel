import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { revokeAllRefreshTokens } from '../../lib/tokens'
import { deleteAvatarFromS3 } from '../../lib/s3'

const patchBody = z.object({
  isFlagged:   z.boolean().optional(),
  isSuspended: z.boolean().optional(),
  isUnlimited: z.boolean().optional(),
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
          lastActiveAt: true, createdAt: true,
          _count: { select: { gameSessions: true } },
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
    const todayStr = new Date().toISOString().slice(0, 10)
    const [user, modeStats, levelStats, quota] = await Promise.all([
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
      app.prisma.$queryRaw<Array<{ mode: string; start_position: number; correct: bigint; total: bigint }>>`
        SELECT
          gs.mode,
          gs."startPosition" AS start_position,
          SUM(gs."correctCount") AS correct,
          SUM(gs."totalCount")   AS total
        FROM "GameSession" gs
        WHERE gs."userId" = ${id}
          AND gs.mode <> 'pi'
          AND gs."totalCount" > 0
        GROUP BY gs.mode, gs."startPosition"
        ORDER BY gs.mode, gs."startPosition"
      `,
      app.prisma.dailyQuota.findUnique({ where: { userId: id } }),
    ])
    if (!user) return reply.status(404).send('Not found')

    const modeStatsFormatted = modeStats.map(s => ({
      mode:         s.mode,
      rounds:       s._count.id,
      answered:     s._sum.totalCount ?? 0,
      correct:      s._sum.correctCount ?? 0,
      pctCorrect:   s._sum.totalCount ? Math.round((s._sum.correctCount ?? 0) / s._sum.totalCount * 100) : null,
    }))

    const totalRounds = modeStatsFormatted.reduce((sum, s) => sum + s.rounds, 0)

    const levelStatsFormatted = levelStats.map(r => ({
      mode:    r.mode,
      level:   r.start_position === 0 ? 'Ukjent' : `Lv ${r.start_position}`,
      correct: Number(r.correct),
      total:   Number(r.total),
      pct:     Number(r.total) > 0 ? Math.round(Number(r.correct) / Number(r.total) * 100) : null,
    }))

    const quotaDisplay = user.isPremium
      ? null
      : { used: quota?.count ?? 0, limit: 20, date: quota?.date ?? todayStr, isToday: quota?.date === todayStr }

    return reply.view('admin/user-detail.ejs', {
      title: `@${user.username}`,
      user,
      modeStats: modeStatsFormatted,
      totalRounds,
      levelStats: levelStatsFormatted,
      quota: quotaDisplay,
    })
  })

  // DELETE /admin/users/:id/avatar — remove custom uploaded avatar
  app.delete('/:id/avatar', async (request, reply) => {
    const { id } = request.params as { id: string }
    const user = await (app.prisma.user as any).findUnique({
      where: { id }, select: { avatarUrl: true },
    })
    if (!user) return reply.status(404).send({ error: 'Not found' })

    if (user.avatarUrl) {
      await deleteAvatarFromS3(app.s3, user.avatarUrl)
      await (app.prisma.user as any).update({ where: { id }, data: { avatarUrl: null } })
    }

    return reply.send({ ok: true })
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
    if (body.data.isSuspended === true) {
      await revokeAllRefreshTokens(app.redis, id)
    }
    return reply.send({ ok: true, isFlagged: user.isFlagged, isSuspended: user.isSuspended, isUnlimited: user.isUnlimited })
  })
}

import type { FastifyInstance } from 'fastify'

export default async function adminStatsRoutes(app: FastifyInstance) {
  app.get('/', async (_request, reply) => {
    const now = new Date()
    const day1  = new Date(now.getTime() - 86_400_000)
    const day30 = new Date(now.getTime() - 30 * 86_400_000)

    const [
      totalUsers, dau, mau, premiumUsers, flaggedUsers, suspendedUsers,
      totalSessions, sessionsToday, openFeedback,
      modePopularity,
    ] = await Promise.all([
      app.prisma.user.count(),
      app.prisma.user.count({ where: { lastActiveAt: { gte: day1 } } }),
      app.prisma.user.count({ where: { lastActiveAt: { gte: day30 } } }),
      app.prisma.user.count({ where: { isPremium: true } }),
      app.prisma.user.count({ where: { isFlagged: true } }),
      app.prisma.user.count({ where: { isSuspended: true } }),
      app.prisma.gameSession.count(),
      app.prisma.gameSession.count({ where: { startedAt: { gte: day1 } } }),
      app.prisma.feedback.count({ where: { status: 'open' } }),
      app.prisma.gameSession.groupBy({
        by: ['mode'],
        _count: { id: true },
        where: { startedAt: { gte: day30 } },
        orderBy: { _count: { id: 'desc' } },
        take: 10,
      }),
    ])

    return reply.view('admin/stats.ejs', {
      title: 'Statistics',
      stats: {
        totalUsers, dau, mau, premiumUsers, flaggedUsers, suspendedUsers,
        totalSessions, sessionsToday, openFeedback,
      },
      modePopularity: modePopularity.map(m => ({ mode: m.mode, count: m._count.id })),
    })
  })
}

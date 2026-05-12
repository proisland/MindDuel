import type { FastifyInstance } from 'fastify'

export default async function adminStatsRoutes(app: FastifyInstance) {
  app.get('/', async (_request, reply) => {
    const now = new Date()
    const day1  = new Date(now.getTime() - 86_400_000)
    const day30 = new Date(now.getTime() - 30 * 86_400_000)

    const [
      totalUsers, dau, mau, premiumUsers, flaggedUsers, suspendedUsers,
      totalSessions, sessionsToday, openFeedback,
      modePopularity, modeAccuracy, localeDistribution, sessionTimeSeries, ageDistribution,
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
      app.prisma.gameSession.groupBy({
        by: ['mode'],
        _sum: { correctCount: true, totalCount: true },
        having: { totalCount: { _sum: { gt: 0 } } },
        orderBy: { mode: 'asc' },
      }),
      app.prisma.user.groupBy({
        by: ['locale'],
        _count: { id: true },
        where: { locale: { not: null } },
        orderBy: { _count: { id: 'desc' } },
        take: 15,
      }),
      app.prisma.$queryRaw<Array<{ date: string; single: bigint; multiplayer: bigint }>>`
        SELECT
          TO_CHAR(DATE("startedAt"), 'YYYY-MM-DD') AS date,
          COUNT(*) FILTER (WHERE "isMultiplayer" = false) AS single,
          COUNT(*) FILTER (WHERE "isMultiplayer" = true)  AS multiplayer
        FROM "GameSession"
        WHERE "startedAt" >= ${day30}
        GROUP BY DATE("startedAt")
        ORDER BY date
      `,
      app.prisma.$queryRaw<Array<{ age_group: string; count: bigint }>>`
        SELECT
          CASE
            WHEN EXTRACT(YEAR FROM AGE("birthDate")) < 13 THEN 'Under 13'
            WHEN EXTRACT(YEAR FROM AGE("birthDate")) < 18 THEN '13–17'
            WHEN EXTRACT(YEAR FROM AGE("birthDate")) < 25 THEN '18–24'
            WHEN EXTRACT(YEAR FROM AGE("birthDate")) < 35 THEN '25–34'
            WHEN EXTRACT(YEAR FROM AGE("birthDate")) < 50 THEN '35–49'
            ELSE '50+'
          END AS age_group,
          COUNT(*) AS count
        FROM "User"
        WHERE "birthDate" IS NOT NULL
        GROUP BY age_group
        ORDER BY count DESC
      `,
    ])

    return reply.view('admin/stats.ejs', {
      title: 'Statistics',
      stats: {
        totalUsers, dau, mau, premiumUsers, flaggedUsers, suspendedUsers,
        totalSessions, sessionsToday, openFeedback,
      },
      modePopularity:  modePopularity.map(m => ({ mode: m.mode, count: m._count.id })),
      modeAccuracy:    modeAccuracy.map(m => ({
        mode:       m.mode,
        correct:    Number(m._sum.correctCount ?? 0),
        total:      Number(m._sum.totalCount ?? 0),
        pct:        m._sum.totalCount ? Math.round(Number(m._sum.correctCount ?? 0) / Number(m._sum.totalCount) * 100) : null,
      })),
      localeDistribution: localeDistribution.map(l => ({ locale: l.locale, count: l._count.id })),
      sessionTimeSeries:  sessionTimeSeries.map(r => ({
        date:        r.date,
        single:      Number(r.single),
        multiplayer: Number(r.multiplayer),
      })),
      ageDistribution: ageDistribution.map(r => ({
        group: r.age_group,
        count: Number(r.count),
      })),
    })
  })
}

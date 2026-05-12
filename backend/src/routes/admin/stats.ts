import type { FastifyInstance } from 'fastify'

export default async function adminStatsRoutes(app: FastifyInstance) {
  app.get('/', async (_request, reply) => {
    const now = new Date()
    const day1  = new Date(now.getTime() - 86_400_000)
    const day30 = new Date(now.getTime() - 30 * 86_400_000)
    const todayStr = now.toISOString().slice(0, 10)

    const [
      totalUsers, dau, mau, premiumUsers, flaggedUsers, suspendedUsers,
      totalSessions, sessionsToday, openFeedback,
      modePopularity, modeAccuracy, localeDistribution, sessionTimeSeries, ageDistribution,
      levelAccuracy, ageAccuracy, quotaStats,
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
      app.prisma.$queryRaw<Array<{ locale: string; count: bigint }>>`
        SELECT locale, COUNT(*) AS count
        FROM "User"
        WHERE locale IS NOT NULL
        GROUP BY locale
        ORDER BY count DESC
        LIMIT 15
      `,
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
      app.prisma.$queryRaw<Array<{ mode: string; start_position: number; correct: bigint; total: bigint }>>`
        SELECT
          gs.mode,
          gs."startPosition" AS start_position,
          SUM(gs."correctCount") AS correct,
          SUM(gs."totalCount")   AS total
        FROM "GameSession" gs
        WHERE gs.mode <> 'pi'
          AND gs."totalCount" > 0
        GROUP BY gs.mode, gs."startPosition"
        ORDER BY gs.mode, gs."startPosition"
      `,
      app.prisma.$queryRaw<Array<{
        mode: string; start_position: number; age_group: string; age_sort: number;
        correct: bigint; total: bigint
      }>>`
        SELECT
          gs.mode,
          gs."startPosition" AS start_position,
          CASE
            WHEN u."birthDate" IS NULL                            THEN 'Ukjent'
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 13       THEN 'Under 13'
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 18       THEN '13–17'
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 25       THEN '18–24'
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 35       THEN '25–34'
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 50       THEN '35–49'
            ELSE '50+'
          END AS age_group,
          CASE
            WHEN u."birthDate" IS NULL                            THEN 99
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 13       THEN 0
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 18       THEN 1
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 25       THEN 2
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 35       THEN 3
            WHEN EXTRACT(YEAR FROM AGE(u."birthDate")) < 50       THEN 4
            ELSE 5
          END AS age_sort,
          SUM(gs."correctCount") AS correct,
          SUM(gs."totalCount")   AS total
        FROM "GameSession" gs
        JOIN "User" u ON u.id = gs."userId"
        WHERE gs.mode <> 'pi'
          AND gs."totalCount" > 0
        GROUP BY gs.mode, gs."startPosition", age_group, age_sort
        ORDER BY gs.mode, gs."startPosition", age_sort
      `,
      app.prisma.$queryRaw<Array<{
        active_today: bigint; hit_limit: bigint; avg_usage: number | null;
        bucket_1_5: bigint; bucket_6_10: bigint; bucket_11_15: bigint;
        bucket_16_19: bigint; bucket_20plus: bigint;
      }>>`
        SELECT
          COUNT(*)                            FILTER (WHERE dq.count > 0)           AS active_today,
          COUNT(*)                            FILTER (WHERE dq.count >= 20)         AS hit_limit,
          ROUND(AVG(dq.count)::numeric, 1)                                          AS avg_usage,
          COUNT(*)                            FILTER (WHERE dq.count BETWEEN 1 AND 5)   AS bucket_1_5,
          COUNT(*)                            FILTER (WHERE dq.count BETWEEN 6 AND 10)  AS bucket_6_10,
          COUNT(*)                            FILTER (WHERE dq.count BETWEEN 11 AND 15) AS bucket_11_15,
          COUNT(*)                            FILTER (WHERE dq.count BETWEEN 16 AND 19) AS bucket_16_19,
          COUNT(*)                            FILTER (WHERE dq.count >= 20)             AS bucket_20plus
        FROM "DailyQuota" dq
        JOIN "User" u ON u.id = dq."userId"
        WHERE dq.date = ${todayStr}
          AND u."isPremium" = false
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
      localeDistribution: localeDistribution.map(l => ({ locale: l.locale, count: Number(l.count) })),
      sessionTimeSeries:  sessionTimeSeries.map(r => ({
        date:        r.date,
        single:      Number(r.single),
        multiplayer: Number(r.multiplayer),
      })),
      ageDistribution: ageDistribution.map(r => ({
        group: r.age_group,
        count: Number(r.count),
      })),
      levelAccuracy: levelAccuracy.map(r => ({
        mode:     r.mode,
        level:    r.start_position === 0 ? 'Ukjent' : `Lv ${r.start_position}`,
        correct:  Number(r.correct),
        total:    Number(r.total),
        pct:      Number(r.total) > 0 ? Math.round(Number(r.correct) / Number(r.total) * 100) : null,
      })),
      ageAccuracy: ageAccuracy.map(r => ({
        mode:     r.mode,
        level:    r.start_position === 0 ? 'Ukjent' : `Lv ${r.start_position}`,
        ageGroup: r.age_group,
        correct:  Number(r.correct),
        total:    Number(r.total),
        pct:      Number(r.total) > 0 ? Math.round(Number(r.correct) / Number(r.total) * 100) : null,
      })),
      quotaStats: quotaStats[0] ? {
        activeToday:  Number(quotaStats[0].active_today),
        hitLimit:     Number(quotaStats[0].hit_limit),
        avgUsage:     quotaStats[0].avg_usage != null ? Number(quotaStats[0].avg_usage) : null,
        bucket1_5:    Number(quotaStats[0].bucket_1_5),
        bucket6_10:   Number(quotaStats[0].bucket_6_10),
        bucket11_15:  Number(quotaStats[0].bucket_11_15),
        bucket16_19:  Number(quotaStats[0].bucket_16_19),
        bucket20plus: Number(quotaStats[0].bucket_20plus),
        todayStr,
      } : null,
    })
  })
}

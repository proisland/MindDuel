import type { FastifyInstance } from 'fastify'

export default async function challengesRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/challenges/daily — deterministic daily challenge based on date
  app.get('/daily', auth, async (_request, reply) => {
    const today = new Date().toISOString().slice(0, 10)

    const modes = await app.prisma.gameMode.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: { slug: true, name: true, nameNo: true, nameEn: true, iconSymbol: true, colorHex: true },
    })

    if (modes.length === 0) return reply.status(404).send({ error: 'No active modes' })

    // Deterministic rotation: days since Unix epoch mod mode count
    const daysSinceEpoch = Math.floor(Date.now() / (1000 * 60 * 60 * 24))
    const mode = modes[daysSinceEpoch % modes.length]

    return reply.send({ date: today, mode })
  })
}

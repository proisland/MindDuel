import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const MODES_CACHE_TTL = 60 // seconds

export default async function modesRoutes(app: FastifyInstance) {
  // GET /v1/modes — active game mode config (cached in Redis)
  app.get('/', async (_request, reply) => {
    const cacheKey = 'modes:active'
    const cached = await app.redis.get(cacheKey)
    if (cached) {
      return reply.send(JSON.parse(cached))
    }

    const modes = await app.prisma.gameMode.findMany({
      where: {
        isActive: true,
        OR: [
          { startsAt: null },
          { startsAt: { lte: new Date() } },
        ],
        AND: [
          {
            OR: [
              { endsAt: null },
              { endsAt: { gte: new Date() } },
            ],
          },
        ],
      },
      orderBy: { sortOrder: 'asc' },
      select: { slug: true, nameNo: true, nameEn: true, iconSymbol: true, colorHex: true, startsAt: true, endsAt: true, sortOrder: true },
    })

    const payload = { modes, fetchedAt: new Date().toISOString() }
    await app.redis.set(cacheKey, JSON.stringify(payload), 'EX', MODES_CACHE_TTL)

    return reply.send(payload)
  })
}

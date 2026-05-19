import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

export default async function avatarsRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/avatars/presets — list of active preset avatars for picker
  app.get('/presets', auth, async (_request, reply) => {
    const presets = await (app.prisma as any).presetAvatar.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: { id: true, url: true, label: true, sortOrder: true },
    })
    return reply.send({ presets })
  })
}

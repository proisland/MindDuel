import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const versionCheckQuery = z.object({
  modes: z.string().min(1), // comma-separated list of mode slugs
})

export default async function questionsRoutes(app: FastifyInstance) {
  // GET /v1/questions/versions — check latest version per mode
  app.get('/versions', async (request, reply) => {
    const query = versionCheckQuery.safeParse(request.query)
    if (!query.success) return reply.status(400).send({ error: 'Missing ?modes= parameter' })

    const slugs = query.data.modes.split(',').map(s => s.trim()).filter(Boolean)

    const packs = await app.prisma.questionPack.findMany({
      where: { mode: { in: slugs }, isActive: true },
      orderBy: [{ mode: 'asc' }, { version: 'desc' }],
      select: { mode: true, version: true },
      distinct: ['mode'],
    })

    const versions: Record<string, number> = {}
    for (const p of packs) {
      versions[p.mode] = p.version
    }

    return reply.send({ versions })
  })

  // GET /v1/questions/:mode — download the active question pack for a mode
  app.get('/:mode', async (request, reply) => {
    const { mode } = request.params as { mode: string }

    const pack = await app.prisma.questionPack.findFirst({
      where: { mode, isActive: true },
      orderBy: { version: 'desc' },
    })

    if (!pack) return reply.status(404).send({ error: 'No active question pack for this mode' })

    return reply.send({
      mode: pack.mode,
      version: pack.version,
      questions: pack.data,
    })
  })
}

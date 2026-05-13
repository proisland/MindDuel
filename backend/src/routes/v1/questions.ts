import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const versionCheckQuery = z.object({
  modes: z.string().min(1), // comma-separated list of mode slugs
  lang:  z.string().optional(),
})

export default async function questionsRoutes(app: FastifyInstance) {
  // GET /v1/questions/versions — check latest version per mode
  // Optional ?lang=xx selects the language to check; falls back en → no.
  app.get('/versions', async (request, reply) => {
    const query = versionCheckQuery.safeParse(request.query)
    if (!query.success) return reply.status(400).send({ error: 'Missing ?modes= parameter' })

    const slugs = query.data.modes.split(',').map(s => s.trim()).filter(Boolean)
    const requestedLang = query.data.lang ?? 'no'

    // Single query for all active packs across the requested modes
    const packs = await app.prisma.questionPack.findMany({
      where: { mode: { in: slugs }, isActive: true },
      orderBy: { version: 'desc' },
      select: { mode: true, language: true, version: true },
    })

    // For each slug, pick best language: requested → en → no
    const langPriority = [...new Set([requestedLang, 'en', 'no'])]
    const versions: Record<string, { version: number; language: string }> = {}
    for (const slug of slugs) {
      const modePacks = packs.filter(p => p.mode === slug)
      for (const lang of langPriority) {
        const pack = modePacks.find(p => p.language === lang)
        if (pack) { versions[slug] = { version: pack.version, language: pack.language }; break }
      }
    }

    return reply.send({ versions })
  })

  // GET /v1/questions/:mode — download the active question pack for a mode
  // Optional ?lang=xx selects the language; falls back en → no.
  app.get('/:mode', async (request, reply) => {
    const { mode } = request.params as { mode: string }
    const { lang } = request.query as { lang?: string }
    const requestedLang = lang ?? 'no'

    const packs = await app.prisma.questionPack.findMany({
      where: { mode, isActive: true },
      orderBy: { version: 'desc' },
    })

    const langPriority = [...new Set([requestedLang, 'en', 'no'])]
    let pack = null
    for (const l of langPriority) {
      pack = packs.find(p => p.language === l) ?? null
      if (pack) break
    }

    if (!pack) return reply.status(404).send({ error: 'No active question pack for this mode' })

    return reply.send({
      mode: pack.mode,
      language: pack.language,
      version: pack.version,
      questions: pack.data,
    })
  })
}

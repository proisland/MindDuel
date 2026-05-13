import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const versionCheckQuery = z.object({
  modes: z.string().min(1), // comma-separated list of mode slugs
  lang:  z.string().optional(),
})

// Returns the best available language pack for a mode given a requested language.
// Falls back: requested lang → "en" → "no".
async function findActivePack(
  prisma: FastifyInstance['prisma'],
  mode: string,
  requestedLang: string,
) {
  const langs = [...new Set([requestedLang, 'en', 'no'])]
  for (const lang of langs) {
    const pack = await prisma.questionPack.findFirst({
      where: { mode, language: lang, isActive: true },
      orderBy: { version: 'desc' },
    })
    if (pack) return pack
  }
  return null
}

export default async function questionsRoutes(app: FastifyInstance) {
  // GET /v1/questions/versions — check latest version per mode
  // Optional ?lang=xx selects the language to check; falls back en → no.
  app.get('/versions', async (request, reply) => {
    const query = versionCheckQuery.safeParse(request.query)
    if (!query.success) return reply.status(400).send({ error: 'Missing ?modes= parameter' })

    const slugs = query.data.modes.split(',').map(s => s.trim()).filter(Boolean)
    const lang = query.data.lang ?? 'no'

    const versions: Record<string, { version: number; language: string }> = {}
    for (const slug of slugs) {
      const pack = await findActivePack(app.prisma, slug, lang)
      if (pack) versions[slug] = { version: pack.version, language: pack.language }
    }

    return reply.send({ versions })
  })

  // GET /v1/questions/:mode — download the active question pack for a mode
  // Optional ?lang=xx selects the language; falls back en → no.
  app.get('/:mode', async (request, reply) => {
    const { mode } = request.params as { mode: string }
    const { lang } = request.query as { lang?: string }

    const pack = await findActivePack(app.prisma, mode, lang ?? 'no')

    if (!pack) return reply.status(404).send({ error: 'No active question pack for this mode' })

    return reply.send({
      mode: pack.mode,
      language: pack.language,
      version: pack.version,
      questions: pack.data,
    })
  })
}

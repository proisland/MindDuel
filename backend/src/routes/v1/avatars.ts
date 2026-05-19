import type { FastifyInstance } from 'fastify'

export default async function avatarsRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/avatars/presets — list of active preset avatars for picker
  app.get('/presets', auth, async (request, reply) => {
    const presets = await (app.prisma as any).presetAvatar.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: { id: true, url: true, labelNo: true, labelEn: true, sortOrder: true },
    })

    const lang = (request.headers['accept-language'] ?? '').match(/\b(nb|no)\b/i) ? 'no' : 'en'

    return reply.send({
      presets: presets.map((p: any) => ({
        id: p.id,
        url: p.url,
        label: lang === 'no' ? (p.labelNo || p.labelEn) : (p.labelEn || p.labelNo),
        sortOrder: p.sortOrder,
      })),
    })
  })
}

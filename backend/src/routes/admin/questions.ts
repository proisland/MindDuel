import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const createPackBody = z.object({
  mode: z.string().min(1),
  questions: z.array(z.object({
    id: z.string(),
    prompt: z.string(),
    options: z.array(z.string()).length(4),
    answer: z.string(),
    level: z.number().int().min(1).max(20),
  })).min(1),
})

export default async function adminQuestionsRoutes(app: FastifyInstance) {
  // GET /admin/questions
  app.get('/', async (_request, reply) => {
    const packs = await app.prisma.questionPack.findMany({
      orderBy: [{ mode: 'asc' }, { version: 'desc' }],
      select: { id: true, mode: true, version: true, isActive: true, createdAt: true },
    })

    const grouped: Record<string, typeof packs> = {}
    for (const p of packs) {
      grouped[p.mode] = grouped[p.mode] ?? []
      grouped[p.mode].push(p)
    }

    return reply.view('admin/questions.ejs', { title: 'Questions', grouped })
  })

  // POST /admin/questions — upload new pack (JSON body)
  app.post('/', async (request, reply) => {
    const body = createPackBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid body', details: body.error.flatten() })
    }

    const latest = await app.prisma.questionPack.findFirst({
      where: { mode: body.data.mode },
      orderBy: { version: 'desc' },
      select: { version: true },
    })

    const version = (latest?.version ?? 0) + 1
    const pack = await app.prisma.questionPack.create({
      data: {
        mode: body.data.mode,
        version,
        data: body.data.questions,
        isActive: false,
      },
    })

    return reply.status(201).send({ id: pack.id, mode: pack.mode, version: pack.version })
  })

  // PATCH /admin/questions/:id/activate — activate and deactivate previous
  app.patch('/:id/activate', async (request, reply) => {
    const { id } = request.params as { id: string }
    const pack = await app.prisma.questionPack.findUnique({ where: { id } })
    if (!pack) return reply.status(404).send({ error: 'Not found' })

    await app.prisma.$transaction([
      app.prisma.questionPack.updateMany({
        where: { mode: pack.mode, isActive: true },
        data: { isActive: false },
      }),
      app.prisma.questionPack.update({
        where: { id },
        data: { isActive: true },
      }),
    ])

    // Invalidate modes cache
    await app.redis.del('modes:active')

    return reply.send({ ok: true })
  })
}

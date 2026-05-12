import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const patchBody = z.object({
  isActive:  z.boolean().optional(),
  startsAt:  z.string().datetime().nullable().optional(),
  endsAt:    z.string().datetime().nullable().optional(),
  sortOrder: z.number().int().optional(),
})

export default async function adminModesRoutes(app: FastifyInstance) {
  // GET /admin/modes
  app.get('/', async (_request, reply) => {
    const modes = await app.prisma.gameMode.findMany({ orderBy: { sortOrder: 'asc' } })
    return reply.view('admin/modes.ejs', { title: 'Game Modes', modes })
  })

  // PATCH /admin/modes/:id
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = patchBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const mode = await app.prisma.gameMode.update({
      where: { id },
      data: {
        ...(body.data.isActive !== undefined && { isActive: body.data.isActive }),
        ...(body.data.startsAt !== undefined && { startsAt: body.data.startsAt ? new Date(body.data.startsAt) : null }),
        ...(body.data.endsAt !== undefined && { endsAt: body.data.endsAt ? new Date(body.data.endsAt) : null }),
        ...(body.data.sortOrder !== undefined && { sortOrder: body.data.sortOrder }),
      },
    })

    await app.redis.del('modes:active')
    return reply.send({ ok: true, isActive: mode.isActive })
  })
}

import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const createBody = z.object({
  url:       z.string().url(),
  label:     z.string().default(''),
  isActive:  z.boolean().default(true),
  sortOrder: z.number().int().optional(),
})

const patchBody = z.object({
  label:     z.string().optional(),
  isActive:  z.boolean().optional(),
  sortOrder: z.number().int().optional(),
})

export default async function adminAvatarsRoutes(app: FastifyInstance) {
  // GET /admin/avatars
  app.get('/', async (_request, reply) => {
    const avatars = await (app.prisma as any).presetAvatar.findMany({
      orderBy: { sortOrder: 'asc' },
    })
    return reply.view('admin/avatars.ejs', { title: 'Preset Avatars', avatars })
  })

  // POST /admin/avatars
  app.post('/', async (request, reply) => {
    const body = createBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: body.error.flatten() })

    let { sortOrder } = body.data
    if (sortOrder === undefined) {
      const last = await (app.prisma as any).presetAvatar.findFirst({
        orderBy: { sortOrder: 'desc' }, select: { sortOrder: true },
      })
      sortOrder = (last?.sortOrder ?? -1) + 1
    }

    const avatar = await (app.prisma as any).presetAvatar.create({
      data: { url: body.data.url, label: body.data.label, isActive: body.data.isActive, sortOrder },
    })
    return reply.status(201).send(avatar)
  })

  // PATCH /admin/avatars/:id
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = patchBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: body.error.flatten() })

    const avatar = await (app.prisma as any).presetAvatar.update({
      where: { id },
      data: {
        ...(body.data.label     !== undefined && { label: body.data.label }),
        ...(body.data.isActive  !== undefined && { isActive: body.data.isActive }),
        ...(body.data.sortOrder !== undefined && { sortOrder: body.data.sortOrder }),
      },
    })
    return reply.send({ ok: true, isActive: avatar.isActive })
  })

  // DELETE /admin/avatars/:id
  app.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    await (app.prisma as any).presetAvatar.delete({ where: { id } })
    return reply.send({ ok: true })
  })
}

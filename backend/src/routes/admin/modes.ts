import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const createBody = z.object({
  slug:        z.string().min(1).regex(/^[a-z0-9_]+$/, 'Slug must be lowercase alphanumeric + underscores'),
  name:        z.string().min(1),
  isActive:    z.boolean().default(false),
  iconSymbol:  z.string().min(1).default('questionmark'),
  colorHex:    z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Must be a 6-digit hex color').default('#6366F1'),
  sortOrder:   z.number().int().optional(),
  startsAt:    z.string().datetime().nullable().optional(),
  endsAt:      z.string().datetime().nullable().optional(),
})

const patchBody = z.object({
  name:        z.string().min(1).optional(),
  isActive:    z.boolean().optional(),
  iconSymbol:  z.string().min(1).optional(),
  colorHex:    z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Must be a 6-digit hex color').optional(),
  startsAt:    z.string().datetime().nullable().optional(),
  endsAt:      z.string().datetime().nullable().optional(),
  sortOrder:   z.number().int().optional(),
})

export default async function adminModesRoutes(app: FastifyInstance) {
  // GET /admin/modes
  app.get('/', async (_request, reply) => {
    const modes = await app.prisma.gameMode.findMany({ orderBy: { sortOrder: 'asc' } })
    return reply.view('admin/modes.ejs', { title: 'Game Modes', modes })
  })

  // POST /admin/modes — create new mode
  app.post('/', async (request, reply) => {
    const body = createBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: body.error.flatten() })

    const existing = await app.prisma.gameMode.findUnique({ where: { slug: body.data.slug } })
    if (existing) return reply.status(409).send({ error: 'Slug already exists' })

    let sortOrder = body.data.sortOrder
    if (sortOrder === undefined) {
      const last = await app.prisma.gameMode.findFirst({ orderBy: { sortOrder: 'desc' }, select: { sortOrder: true } })
      sortOrder = (last?.sortOrder ?? -1) + 1
    }

    const { startsAt, endsAt, sortOrder: _so, ...rest } = body.data
    const mode = await app.prisma.gameMode.create({
      data: {
        ...rest,
        sortOrder,
        ...(startsAt != null && { startsAt: new Date(startsAt) }),
        ...(endsAt != null && { endsAt: new Date(endsAt) }),
      },
    })
    await app.redis.del('modes:active')
    return reply.status(201).send(mode)
  })

  // PATCH /admin/modes/reorder — drag-and-drop sort order (must be before /:id)
  app.patch('/reorder', async (request, reply) => {
    const body = z.object({ ids: z.array(z.string().min(1)) }).safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const { ids } = body.data
    const existing = await app.prisma.gameMode.findMany({ select: { id: true } })
    const existingIds = new Set(existing.map(m => m.id))
    if (ids.length !== existingIds.size || !ids.every(id => existingIds.has(id))) {
      return reply.status(400).send({ error: 'ids must match all existing modes exactly' })
    }

    await app.prisma.$transaction(
      ids.map((id, index) =>
        app.prisma.gameMode.update({ where: { id }, data: { sortOrder: index } })
      )
    )

    await app.redis.del('modes:active')
    return reply.send({ ok: true })
  })

  // PATCH /admin/modes/:id
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = patchBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const mode = await app.prisma.gameMode.update({
      where: { id },
      data: {
        ...(body.data.name        !== undefined && { name: body.data.name }),
        ...(body.data.isActive    !== undefined && { isActive: body.data.isActive }),
        ...(body.data.iconSymbol  !== undefined && { iconSymbol: body.data.iconSymbol }),
        ...(body.data.colorHex    !== undefined && { colorHex: body.data.colorHex }),
        ...(body.data.sortOrder   !== undefined && { sortOrder: body.data.sortOrder }),
        ...(body.data.startsAt    !== undefined && { startsAt: body.data.startsAt ? new Date(body.data.startsAt) : null }),
        ...(body.data.endsAt      !== undefined && { endsAt: body.data.endsAt ? new Date(body.data.endsAt) : null }),
      },
    })

    await app.redis.del('modes:active')
    return reply.send({ ok: true, isActive: mode.isActive })
  })

  // DELETE /admin/modes/:id
  app.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    await app.prisma.gameMode.delete({ where: { id } })
    await app.redis.del('modes:active')
    return reply.send({ ok: true })
  })
}

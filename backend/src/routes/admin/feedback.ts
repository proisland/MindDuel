import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const respondBody = z.object({
  response: z.string().min(1),
  status: z.enum(['open', 'in_progress', 'closed']).default('closed'),
})

export default async function adminFeedbackRoutes(app: FastifyInstance) {
  // GET /admin/feedback
  app.get('/', async (request, reply) => {
    const { status, page } = request.query as Record<string, string>
    const take = 30
    const skip = (parseInt(page ?? '1', 10) - 1) * take

    const where: any = status ? { status } : {}

    const [tickets, total] = await Promise.all([
      app.prisma.feedback.findMany({
        where,
        include: { user: { select: { id: true, username: true, avatarEmoji: true } } },
        orderBy: { createdAt: 'desc' },
        skip, take,
      }),
      app.prisma.feedback.count({ where }),
    ])

    return reply.view('admin/feedback.ejs', {
      title: 'Feedback', tickets, total,
      page: parseInt(page ?? '1', 10), take,
      statusFilter: status ?? '',
    })
  })

  // PATCH /admin/feedback/:id — respond and/or close
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = respondBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    await app.prisma.feedback.update({
      where: { id },
      data: {
        adminResponse: body.data.response,
        status: body.data.status,
        respondedAt: new Date(),
      },
    })

    return reply.send({ ok: true })
  })
}

import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { sendPush } from '../../lib/apns'

const respondBody = z.object({
  response: z.string().min(1),
  status:   z.enum(['open', 'in_progress', 'closed']).default('in_progress'),
  notify:   z.boolean().default(false),
})

const commentBody = z.object({
  body:   z.string().min(1),
  notify: z.boolean().default(false),
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
        include: {
          user:     { select: { id: true, username: true, avatarEmoji: true } },
          comments: { orderBy: { createdAt: 'asc' } },
        },
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

  // PATCH /admin/feedback/:id — update response/status
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = respondBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const ticket = await app.prisma.feedback.update({
      where: { id },
      data: {
        adminResponse: body.data.response,
        status:        body.data.status,
        respondedAt:   new Date(),
      },
      include: { user: { include: { pushTokens: true } } },
    })

    if (body.data.notify && ticket.user.pushTokens.length > 0) {
      await Promise.allSettled(
        ticket.user.pushTokens.map(t =>
          sendPush(t.deviceToken, 'Svar på tilbakemelding', body.data.response)
        )
      )
    }

    return reply.send({ ok: true })
  })

  // POST /admin/feedback/:id/comments — add comment without changing status
  app.post('/:id/comments', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = commentBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const ticket = await app.prisma.feedback.findUnique({
      where: { id },
      include: { user: { include: { pushTokens: true } } },
    })
    if (!ticket) return reply.status(404).send({ error: 'Not found' })

    const comment = await app.prisma.feedbackComment.create({
      data: { feedbackId: id, body: body.data.body, notified: body.data.notify },
    })

    if (body.data.notify && ticket.user.pushTokens.length > 0) {
      await Promise.allSettled(
        ticket.user.pushTokens.map(t =>
          sendPush(t.deviceToken, 'Ny kommentar på tilbakemelding', body.data.body)
        )
      )
    }

    return reply.send({ ok: true, comment })
  })

  // DELETE /admin/feedback/:id
  app.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    await app.prisma.feedback.delete({ where: { id } })
    return reply.send({ ok: true })
  })
}

import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import crypto from 'node:crypto'
import { sendPush } from '../../lib/apns'

const patchBody = z.object({
  status:   z.enum(['open', 'in_progress', 'closed']).optional(),
  response: z.string().min(1).optional(),
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

    const [ticketsBase, total] = await Promise.all([
      app.prisma.feedback.findMany({
        where,
        include: {
          user: { select: { id: true, username: true, avatarEmoji: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip, take,
      }),
      app.prisma.feedback.count({ where }),
    ])

    // Fetch imageUrl + comments via raw SQL (fields not in stale Prisma client)
    type RawImageUrl = { id: string; imageUrl: string | null }
    type RawComment = { id: string; feedbackId: string; body: string; notified: boolean; createdAt: Date }

    const ticketIds = ticketsBase.map(t => t.id)
    const [rawImageUrls, rawComments] = await Promise.all([
      ticketIds.length > 0
        ? app.prisma.$queryRaw<RawImageUrl[]>`
            SELECT id, "imageUrl" FROM "Feedback" WHERE id = ANY(${ticketIds})
          `
        : Promise.resolve([] as RawImageUrl[]),
      ticketIds.length > 0
        ? app.prisma.$queryRaw<RawComment[]>`
            SELECT id, "feedbackId", body, notified, "createdAt"
            FROM "FeedbackComment"
            WHERE "feedbackId" = ANY(${ticketIds})
            ORDER BY "createdAt" ASC
          `
        : Promise.resolve([] as RawComment[]),
    ])

    const imageUrlById = new Map(rawImageUrls.map(r => [r.id, r.imageUrl]))
    const commentsByTicket = new Map<string, RawComment[]>()
    for (const c of rawComments) {
      if (!commentsByTicket.has(c.feedbackId)) commentsByTicket.set(c.feedbackId, [])
      commentsByTicket.get(c.feedbackId)!.push(c)
    }

    const tickets = ticketsBase.map(t => ({
      ...t,
      imageUrl: imageUrlById.get(t.id) ?? null,
      comments: commentsByTicket.get(t.id) ?? [],
    }))

    return reply.view('admin/feedback.ejs', {
      title: 'Feedback', tickets, total,
      page: parseInt(page ?? '1', 10), take,
      statusFilter: status ?? '',
    })
  })

  // PATCH /admin/feedback/:id — update status (and optionally response)
  app.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const body = patchBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const data: Record<string, unknown> = {}
    if (body.data.status)   data.status      = body.data.status
    if (body.data.response) { data.adminResponse = body.data.response; data.respondedAt = new Date() }

    const ticket = await app.prisma.feedback.update({
      where: { id },
      data,
      include: { user: { include: { pushTokens: true } } },
    })

    if (body.data.notify && body.data.response && ticket.user.pushTokens.length > 0) {
      await Promise.allSettled(
        ticket.user.pushTokens.map(t =>
          sendPush(t.deviceToken, 'Svar på tilbakemelding', body.data.response!)
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

    const commentId = crypto.randomUUID()
    await app.prisma.$executeRaw`
      INSERT INTO "FeedbackComment" (id, "feedbackId", body, notified, "createdAt")
      VALUES (${commentId}, ${id}, ${body.data.body}, ${body.data.notify}, NOW())
    `
    const comment = { id: commentId, feedbackId: id, body: body.data.body, notified: body.data.notify }

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

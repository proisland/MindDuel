import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const createBody = z.object({
  message: z.string().min(1).max(2000),
})

export default async function feedbackRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // POST /v1/feedback
  app.post('/', auth, async (request, reply) => {
    const body = createBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const ticket = await app.prisma.feedback.create({
      data: { userId: request.userId, message: body.data.message },
    })

    return reply.status(201).send({ id: ticket.id, status: ticket.status })
  })

  // GET /v1/feedback — my tickets
  app.get('/', auth, async (request, reply) => {
    const tickets = await app.prisma.feedback.findMany({
      where: { userId: request.userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true, message: true, status: true,
        adminResponse: true, respondedAt: true, createdAt: true,
      },
    })

    return reply.send({ tickets })
  })
}

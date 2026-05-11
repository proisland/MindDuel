import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const eventSchema = z.object({
  eventType: z.string().min(1).max(64),
  properties: z.record(z.unknown()).default({}),
  occurredAt: z.string().datetime().optional(),
})

const batchBody = z.object({
  events: z.array(eventSchema).min(1).max(100),
})

export default async function telemetryRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // POST /v1/telemetry — batch event ingestion
  app.post('/', auth, async (request, reply) => {
    const body = batchBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body', details: body.error.flatten() })

    await app.prisma.telemetryEvent.createMany({
      data: body.data.events.map(e => ({
        userId: request.userId,
        eventType: e.eventType,
        properties: e.properties as object,
        createdAt: e.occurredAt ? new Date(e.occurredAt) : new Date(),
      })),
    })

    return reply.status(204).send()
  })
}

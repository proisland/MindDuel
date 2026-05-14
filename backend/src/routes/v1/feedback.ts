import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { config } from '../../config'

const createBody = z.object({
  message:  z.string().min(1).max(2000),
  imageUrl: z.string().url().nullish(),
})

export default async function feedbackRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // POST /v1/feedback
  app.post('/', auth, async (request, reply) => {
    const body = createBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const ticket = await app.prisma.feedback.create({
      data: {
        userId:  request.userId,
        message: body.data.message,
      },
    })

    if (body.data.imageUrl) {
      await app.prisma.$executeRaw`
        UPDATE "Feedback" SET "imageUrl" = ${body.data.imageUrl} WHERE id = ${ticket.id}
      `
    }

    return reply.status(201).send({ id: ticket.id, status: ticket.status })
  })

  // POST /v1/feedback/upload-url — presigned S3 PUT URL for feedback image
  app.post('/upload-url', auth, async (request, reply) => {
    const key = `feedback/${request.userId}/${Date.now()}.jpg`
    const command = new PutObjectCommand({
      Bucket:      config.s3.bucket,
      Key:         key,
      ContentType: 'image/jpeg',
    })
    const uploadUrl = await getSignedUrl(app.s3, command, { expiresIn: 300 })
    const publicUrl = `${config.s3.publicUrl}/${key}`
    return reply.send({ uploadUrl, publicUrl })
  })

  // GET /v1/feedback — my tickets
  app.get('/', auth, async (request, reply) => {
    const tickets = await app.prisma.feedback.findMany({
      where: { userId: request.userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true, message: true, status: true, imageUrl: true,
        adminResponse: true, respondedAt: true, createdAt: true,
        comments: { select: { body: true, createdAt: true }, orderBy: { createdAt: 'asc' } },
      },
    })

    return reply.send({ tickets })
  })
}

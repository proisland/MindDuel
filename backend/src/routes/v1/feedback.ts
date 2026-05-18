import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { config } from '../../config'

const NOTIFY_EMAIL = 'petter.roisland@gmail.com'

const createBody = z.object({
  message:  z.string().min(1).max(2000),
  imageUrl: z.string().url().nullish(),
})

async function sendFeedbackEmail(ticketId: string, username: string, message: string, imageUrl?: string | null) {
  const apiKey = process.env.RESEND_API_KEY
  if (!apiKey) {
    console.warn('[email] RESEND_API_KEY not set — skipping feedback email')
    return
  }

  const imageHtml = imageUrl ? `<p><img src="${imageUrl}" style="max-width:400px" /></p>` : ''
  const html = `
    <h2>Ny tilbakemelding (#${ticketId.slice(0, 8)})</h2>
    <p><strong>Fra:</strong> @${username}</p>
    <pre style="background:#f4f4f4;padding:12px;border-radius:6px;white-space:pre-wrap">${message}</pre>
    ${imageHtml}
  `

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'MindDuel <onboarding@resend.dev>',
      to: [NOTIFY_EMAIL],
      subject: `[MindDuel tilbakemelding] ${message.slice(0, 60).replace(/\n/g, ' ')}`,
      html,
    }),
  }).catch((err: unknown) => { console.error('[email] fetch error:', err); return null })

  if (res && !res.ok) {
    const body = await res.text().catch(() => '')
    console.error(`[email] Resend error ${res.status}:`, body)
  }
}

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
      include: { user: { select: { username: true } } },
    })

    if (body.data.imageUrl) {
      await app.prisma.$executeRaw`
        UPDATE "Feedback" SET "imageUrl" = ${body.data.imageUrl} WHERE id = ${ticket.id}
      `
    }

    const username = (ticket as any).user?.username ?? 'ukjent'
    sendFeedbackEmail(ticket.id, username, body.data.message, body.data.imageUrl).catch(() => {})

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

    // Replace stored private S3 URLs with 1-hour presigned GET URLs
    const ticketsWithUrls = await Promise.all(tickets.map(async t => {
      if (!t.imageUrl) return t
      try {
        const key = t.imageUrl.replace(config.s3.publicUrl + '/', '')
        const cmd = new GetObjectCommand({ Bucket: config.s3.bucket, Key: key })
        const signedUrl = await getSignedUrl(app.s3, cmd, { expiresIn: 3600 })
        return { ...t, imageUrl: signedUrl }
      } catch {
        return t
      }
    }))

    return reply.send({ tickets: ticketsWithUrls })
  })
}

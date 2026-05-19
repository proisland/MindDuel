import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { randomUUID } from 'node:crypto'
import { config } from '../../config'
import { deleteS3Key, uploadJpegToS3 } from '../../lib/s3'

const createBody = z.object({
  data:      z.string().min(1),
  labelNo:   z.string().default(''),
  labelEn:   z.string().default(''),
  isActive:  z.boolean().default(true),
  sortOrder: z.number().int().optional(),
})

const patchBody = z.object({
  labelNo:   z.string().optional(),
  labelEn:   z.string().optional(),
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

  // POST /admin/avatars — upload image + bilingual labels
  app.post('/', async (request, reply) => {
    const body = createBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: body.error.flatten() })

    const imageBuffer = Buffer.from(body.data.data, 'base64')
    if (imageBuffer.byteLength > 5 * 1024 * 1024) {
      return reply.status(413).send({ error: 'Image too large (max 5 MB)' })
    }

    let { sortOrder } = body.data
    if (sortOrder === undefined) {
      const last = await (app.prisma as any).presetAvatar.findFirst({
        orderBy: { sortOrder: 'desc' }, select: { sortOrder: true },
      })
      sortOrder = (last?.sortOrder ?? -1) + 1
    }

    const key = `preset-avatars/${randomUUID()}.jpg`
    let url: string
    try {
      app.log.info({ key, bucket: config.s3.bucket, endpoint: config.s3.endpoint }, 'avatar upload start')
      url = await uploadJpegToS3(app.s3, key, imageBuffer)
      app.log.info({ key }, 'avatar upload ok')
    } catch (err) {
      app.log.error({ err, key }, 'avatar S3 upload failed')
      return reply.status(500).send({ error: 'S3 upload failed', detail: String(err) })
    }

    const avatar = await (app.prisma as any).presetAvatar.create({
      data: {
        url,
        labelNo: body.data.labelNo,
        labelEn: body.data.labelEn,
        isActive: body.data.isActive,
        sortOrder,
      },
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
        ...(body.data.labelNo   !== undefined && { labelNo: body.data.labelNo }),
        ...(body.data.labelEn   !== undefined && { labelEn: body.data.labelEn }),
        ...(body.data.isActive  !== undefined && { isActive: body.data.isActive }),
        ...(body.data.sortOrder !== undefined && { sortOrder: body.data.sortOrder }),
      },
    })
    return reply.send({ ok: true, isActive: avatar.isActive })
  })

  // DELETE /admin/avatars/:id — also removes the image from S3
  app.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const avatar = await (app.prisma as any).presetAvatar.findUnique({
      where: { id }, select: { url: true },
    })
    if (!avatar) return reply.status(404).send({ error: 'Not found' })

    // Extract key from public URL and delete from S3
    const prefix = config.s3.publicUrl + '/'
    if (avatar.url.startsWith(prefix)) {
      await deleteS3Key(app.s3, avatar.url.slice(prefix.length))
    }

    await (app.prisma as any).presetAvatar.delete({ where: { id } })
    return reply.send({ ok: true })
  })
}

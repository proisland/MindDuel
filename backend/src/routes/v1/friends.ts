import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const requestBody = z.object({ username: z.string().min(1) })
const respondBody = z.object({
  fromUserId: z.string().min(1),
  action: z.enum(['accept', 'decline']),
})

export default async function friendsRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // GET /v1/friends — my friend list
  app.get('/', auth, async (request, reply) => {
    const friendships = await app.prisma.friendship.findMany({
      where: {
        OR: [{ senderId: request.userId }, { receiverId: request.userId }],
      },
      include: {
        sender:   { select: { id: true, username: true, avatarEmoji: true, lastActiveAt: true } },
        receiver: { select: { id: true, username: true, avatarEmoji: true, lastActiveAt: true } },
      },
    })

    const friends = friendships.map(f => {
      const friend = f.senderId === request.userId ? f.receiver : f.sender
      return friend
    })

    return reply.send({ friends })
  })

  // GET /v1/friends/requests — pending incoming requests
  app.get('/requests', auth, async (request, reply) => {
    const requests = await app.prisma.friendRequest.findMany({
      where: { toUserId: request.userId },
      include: {
        from: { select: { id: true, username: true, avatarEmoji: true } },
      },
      orderBy: { createdAt: 'desc' },
    })

    return reply.send({ requests: requests.map(r => ({ ...r.from, requestId: r.id, createdAt: r.createdAt })) })
  })

  // POST /v1/friends/requests — send a request by username
  app.post('/requests', auth, async (request, reply) => {
    const body = requestBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const target = await app.prisma.user.findUnique({
      where: { username: body.data.username },
      select: { id: true },
    })
    if (!target) return reply.status(404).send({ error: 'User not found' })
    if (target.id === request.userId) return reply.status(400).send({ error: 'Cannot add yourself' })

    // Already friends?
    const existing = await app.prisma.friendship.findFirst({
      where: {
        OR: [
          { senderId: request.userId, receiverId: target.id },
          { senderId: target.id, receiverId: request.userId },
        ],
      },
    })
    if (existing) return reply.status(409).send({ error: 'Already friends' })

    // Already requested?
    const pending = await app.prisma.friendRequest.findUnique({
      where: { fromUserId_toUserId: { fromUserId: request.userId, toUserId: target.id } },
    })
    if (pending) return reply.status(409).send({ error: 'Request already sent' })

    await app.prisma.friendRequest.create({
      data: { fromUserId: request.userId, toUserId: target.id },
    })

    return reply.status(201).send({ message: 'Request sent' })
  })

  // POST /v1/friends/requests/respond — accept or decline
  app.post('/requests/respond', auth, async (request, reply) => {
    const body = respondBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const req = await app.prisma.friendRequest.findUnique({
      where: { fromUserId_toUserId: { fromUserId: body.data.fromUserId, toUserId: request.userId } },
    })
    if (!req) return reply.status(404).send({ error: 'Request not found' })

    await app.prisma.$transaction(async (tx) => {
      await tx.friendRequest.delete({ where: { id: req.id } })
      if (body.data.action === 'accept') {
        await tx.friendship.create({
          data: { senderId: body.data.fromUserId, receiverId: request.userId },
        })
      }
    })

    return reply.send({ accepted: body.data.action === 'accept' })
  })

  // DELETE /v1/friends/:userId — remove a friend
  app.delete('/:userId', auth, async (request, reply) => {
    const { userId: friendId } = request.params as { userId: string }

    await app.prisma.friendship.deleteMany({
      where: {
        OR: [
          { senderId: request.userId, receiverId: friendId },
          { senderId: friendId, receiverId: request.userId },
        ],
      },
    })

    return reply.status(204).send()
  })
}

import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { sendPush } from '../../lib/apns'

const requestBody = z.object({ username: z.string().min(1) })
const respondBody = z.object({
  requestId: z.string().min(1),
  accept: z.boolean(),
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
        sender:   { select: { id: true, username: true, avatarEmoji: true, avatarUrl: true, isPremium: true, lastActiveAt: true } },
        receiver: { select: { id: true, username: true, avatarEmoji: true, avatarUrl: true, isPremium: true, lastActiveAt: true } },
      },
    })

    const friends = friendships.map(f => {
      const friend = f.senderId === request.userId ? f.receiver : f.sender
      return {
        id: friend.id,
        username: friend.username,
        avatarEmoji: friend.avatarEmoji,
        avatarUrl: (friend as any).avatarUrl ?? null,
        isPremium: friend.isPremium,
        lastActiveAt: friend.lastActiveAt,
      }
    })

    return reply.send({ friends })
  })

  // GET /v1/friends/requests — pending requests (sent + received)
  app.get('/requests', auth, async (request, reply) => {
    const received = await app.prisma.friendRequest.findMany({
      where: { toUserId: request.userId },
      include: {
        from: { select: { id: true, username: true, avatarEmoji: true } },
      },
      orderBy: { createdAt: 'desc' },
    })

    const sent = await app.prisma.friendRequest.findMany({
      where: { fromUserId: request.userId },
      include: {
        to: { select: { id: true, username: true } },
      },
      orderBy: { createdAt: 'desc' },
    })

    return reply.send({
      received: received.map(r => ({
        id: r.id,
        fromUserId: r.fromUserId,
        toUserId: r.toUserId,
        fromUsername: r.from.username,
        fromAvatarEmoji: r.from.avatarEmoji,
        createdAt: r.createdAt,
      })),
      sent: sent.map(r => ({
        id: r.id,
        fromUserId: r.fromUserId,
        toUserId: r.toUserId,
        toUsername: r.to.username,
        createdAt: r.createdAt,
      })),
    })
  })

  // POST /v1/friends/requests — send a request by username
  app.post('/requests', auth, async (request, reply) => {
    const body = requestBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const [target, sender] = await Promise.all([
      app.prisma.user.findUnique({ where: { username: body.data.username }, select: { id: true, username: true } }),
      app.prisma.user.findUnique({ where: { id: request.userId }, select: { username: true } }),
    ])
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

    // Already requested (same direction)?
    const pending = await app.prisma.friendRequest.findUnique({
      where: { fromUserId_toUserId: { fromUserId: request.userId, toUserId: target.id } },
    })
    if (pending) return reply.status(409).send({ error: 'Request already sent' })

    // Reverse request exists — auto-accept to create friendship immediately
    const reverseRequest = await app.prisma.friendRequest.findUnique({
      where: { fromUserId_toUserId: { fromUserId: target.id, toUserId: request.userId } },
    })
    if (reverseRequest) {
      await app.prisma.$transaction(async (tx) => {
        await tx.friendRequest.delete({ where: { id: reverseRequest.id } })
        await tx.friendship.create({
          data: { senderId: target.id, receiverId: request.userId },
        })
      })
      const senderName = sender?.username ?? 'Noen'
      const targetName = target.username
      // Notify target: their original request was accepted
      app.prisma.pushToken.findMany({ where: { userId: target.id } }).then(tokens => {
        tokens.forEach(({ deviceToken }) =>
          sendPush(deviceToken, 'Ny venn! 🎉', `${senderName} og du er nå venner`, { kind: 'newFriend' }).catch(() => {}),
        )
      }).catch(() => {})
      // Notify sender: their request was auto-accepted
      app.prisma.pushToken.findMany({ where: { userId: request.userId } }).then(tokens => {
        tokens.forEach(({ deviceToken }) =>
          sendPush(deviceToken, 'Ny venn! 🎉', `Du og ${targetName} er nå venner`, { kind: 'newFriend' }).catch(() => {}),
        )
      }).catch(() => {})
      return reply.status(201).send({ friendshipCreated: true })
    }

    const createdRequest = await app.prisma.friendRequest.create({
      data: { fromUserId: request.userId, toUserId: target.id },
    })

    // Fire-and-forget push notification to the request recipient
    const senderName = sender?.username ?? 'Noen'
    app.prisma.pushToken.findMany({ where: { userId: target.id } }).then(tokens => {
      tokens.forEach(({ deviceToken }) =>
        sendPush(deviceToken, 'Venneforespørsel', `${senderName} vil være venner med deg`, {
          kind: 'friendRequest',
          fromUsername: senderName,
          requestId: createdRequest.id,
        }).catch(() => {}),
      )
    }).catch(() => {})

    return reply.status(201).send({ message: 'Request sent' })
  })

  // POST /v1/friends/requests/respond — accept or decline
  app.post('/requests/respond', auth, async (request, reply) => {
    const body = respondBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const req = await app.prisma.friendRequest.findUnique({
      where: { id: body.data.requestId },
    })
    if (!req) return reply.status(404).send({ error: 'Request not found' })
    if (req.toUserId !== request.userId) return reply.status(403).send({ error: 'Forbidden' })

    await app.prisma.$transaction(async (tx) => {
      await tx.friendRequest.delete({ where: { id: req.id } })
      if (body.data.accept) {
        await tx.friendship.create({
          data: { senderId: req.fromUserId, receiverId: request.userId },
        })
      }
    })

    // Notify the original sender that their request was accepted
    if (body.data.accept) {
      const accepter = await app.prisma.user.findUnique({
        where: { id: request.userId },
        select: { username: true },
      })
      const accepterName = accepter?.username ?? 'Noen'
      app.prisma.pushToken.findMany({ where: { userId: req.fromUserId } }).then(tokens => {
        tokens.forEach(({ deviceToken }) =>
          sendPush(deviceToken, 'Ny venn! 🎉', `${accepterName} godkjente venneforespørselen din`, { kind: 'newFriend' }).catch(() => {}),
        )
      }).catch(() => {})
    }

    return reply.send({ accepted: body.data.accept })
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

  // GET /v1/friends/suggestions — friends-of-friends ranked by mutual friends + shared modes
  app.get('/suggestions', auth, async (request, reply) => {
    // My friend IDs
    const myFriendships = await app.prisma.friendship.findMany({
      where: { OR: [{ senderId: request.userId }, { receiverId: request.userId }] },
      select: { senderId: true, receiverId: true },
    })
    const myFriendIds = new Set(
      myFriendships.map(f => f.senderId === request.userId ? f.receiverId : f.senderId),
    )

    if (myFriendIds.size === 0) return reply.send({ suggestions: [] })

    // All friendships involving my friends (gives 2nd-degree candidates)
    const fofFriendships = await app.prisma.friendship.findMany({
      where: {
        OR: [
          { senderId: { in: Array.from(myFriendIds) } },
          { receiverId: { in: Array.from(myFriendIds) } },
        ],
      },
      select: { senderId: true, receiverId: true },
    })

    // Count mutual friends per candidate
    const mutualCountMap = new Map<string, number>()
    for (const f of fofFriendships) {
      const candidateId = myFriendIds.has(f.senderId) ? f.receiverId : f.senderId
      if (candidateId === request.userId || myFriendIds.has(candidateId)) continue
      mutualCountMap.set(candidateId, (mutualCountMap.get(candidateId) ?? 0) + 1)
    }

    if (mutualCountMap.size === 0) return reply.send({ suggestions: [] })

    // Filter out users with existing pending requests (sent or received)
    const pendingRequests = await app.prisma.friendRequest.findMany({
      where: { OR: [{ fromUserId: request.userId }, { toUserId: request.userId }] },
      select: { fromUserId: true, toUserId: true },
    })
    const pendingIds = new Set(
      pendingRequests.map(r => r.fromUserId === request.userId ? r.toUserId : r.fromUserId),
    )
    const candidateIds = Array.from(mutualCountMap.keys()).filter(id => !pendingIds.has(id))
    if (candidateIds.length === 0) return reply.send({ suggestions: [] })

    // My progression modes
    const myProgressions = await app.prisma.progression.findMany({
      where: { userId: request.userId },
      select: { mode: true },
    })
    const myModes = new Set(myProgressions.map(p => p.mode))

    // Candidates' progression modes
    const candidateProgressions = await app.prisma.progression.findMany({
      where: { userId: { in: candidateIds } },
      select: { userId: true, mode: true },
    })
    const candidateModeMap = new Map<string, Set<string>>()
    for (const p of candidateProgressions) {
      if (!candidateModeMap.has(p.userId)) candidateModeMap.set(p.userId, new Set())
      candidateModeMap.get(p.userId)!.add(p.mode)
    }

    // Score and sort candidates
    const scored = candidateIds
      .map(id => {
        const mutualCount = mutualCountMap.get(id) ?? 0
        const modes = candidateModeMap.get(id) ?? new Set()
        const sharedModes = [...myModes].filter(m => modes.has(m)).length
        return { id, score: mutualCount * 3 + sharedModes, mutualCount, sharedModes }
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, 10)

    // Fetch user details, filtering out flagged/suspended
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const users: any[] = await app.prisma.user.findMany({
      where: { id: { in: scored.map(s => s.id) }, isFlagged: false, isSuspended: false },
      select: { id: true, username: true, avatarEmoji: true, avatarUrl: true, isPremium: true },
    })
    const userMap = new Map(users.map(u => [u.id, u]))

    const suggestions = scored
      .filter(s => userMap.has(s.id))
      .map(s => {
        const u = userMap.get(s.id)!
        return {
          id: u.id,
          username: u.username,
          avatarEmoji: u.avatarEmoji,
          avatarUrl: u.avatarUrl ?? null,
          isPremium: u.isPremium,
          mutualFriendsCount: s.mutualCount,
          sharedModesCount: s.sharedModes,
        }
      })

    return reply.send({ suggestions })
  })
}

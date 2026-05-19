import type { FastifyInstance } from 'fastify'

const KUDOS_WINDOW_MS  = 7 * 24 * 60 * 60 * 1000
const FEED_WINDOW_MS   = 7 * 24 * 60 * 60 * 1000

export default async function activityRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // POST /v1/activity/:roomId/kudos — send kudos to your opponent in a finished room
  app.post('/:roomId/kudos', auth, async (request: any, reply) => {
    const { roomId } = request.params as { roomId: string }

    const room = await app.prisma.multiplayerRoom.findUnique({
      where: { id: roomId },
      include: { participants: { select: { userId: true } } },
    })
    if (!room) return reply.status(404).send({ error: 'Room not found' })
    if (room.status !== 'finished') return reply.status(400).send({ error: 'Game not finished' })

    const isParticipant = room.participants.some(p => p.userId === request.userId)
    if (!isParticipant) return reply.status(403).send({ error: 'Not a participant' })

    const opponent = room.participants.find(p => p.userId !== request.userId)
    if (!opponent) return reply.status(400).send({ error: 'No opponent to kudos' })

    await app.prisma.activityKudos.upsert({
      where: { fromUserId_roomId: { fromUserId: request.userId, roomId } },
      update: {},
      create: { fromUserId: request.userId, toUserId: opponent.userId, roomId },
    })

    return reply.status(201).send({ ok: true })
  })

  // GET /v1/activity/kudos/unread — count kudos received in the last 7 days
  app.get('/kudos/unread', auth, async (request: any, reply) => {
    const since = new Date(Date.now() - KUDOS_WINDOW_MS)
    const count = await app.prisma.activityKudos.count({
      where: { toUserId: request.userId, createdAt: { gte: since } },
    })
    return reply.send({ count })
  })

  // GET /v1/activity/feed — social activity feed (new friends + active streaks)
  app.get('/feed', auth, async (request: any, reply) => {
    const since = new Date(Date.now() - FEED_WINDOW_MS)

    // Resolve friend IDs
    const friendships = await app.prisma.friendship.findMany({
      where: { OR: [{ senderId: request.userId }, { receiverId: request.userId }] },
      select: { senderId: true, receiverId: true },
    })
    const friendIds = friendships.map((f: any) =>
      f.senderId === request.userId ? f.receiverId : f.senderId,
    )
    const allIds = [request.userId, ...friendIds]

    // New friendships in the last 7 days involving the user or their friends
    const recentFriendships = await app.prisma.friendship.findMany({
      where: {
        createdAt: { gte: since },
        OR: [{ senderId: { in: allIds } }, { receiverId: { in: allIds } }],
      },
      include: {
        sender:   { select: { id: true, username: true, avatarEmoji: true, avatarUrl: true } } as any,
        receiver: { select: { id: true, username: true, avatarEmoji: true, avatarUrl: true } } as any,
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    })

    // Active streaks (≥ 3 days, played today or yesterday) for user + friends
    const today     = new Date().toISOString().slice(0, 10)
    const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10)

    const activeStreaks = await app.prisma.progression.findMany({
      where: {
        userId: { in: allIds },
        currentStreak: { gte: 3 },
        lastPlayedDate: { in: [today, yesterday] },
      },
      include: { user: { select: { id: true, username: true, avatarEmoji: true, avatarUrl: true } } as any },
      orderBy: { currentStreak: 'desc' },
      take: 10,
    })

    // Resolve mode display names from the GameMode table
    const modeSlugs = [...new Set(activeStreaks.map((p: any) => p.mode))] as string[]
    const modeRows = modeSlugs.length > 0
      ? await app.prisma.gameMode.findMany({
          where: { slug: { in: modeSlugs } },
          select: { slug: true, nameNo: true, nameEn: true },
        })
      : []
    const modeNameMap = new Map(modeRows.map((m: any) => [m.slug, m.nameNo || m.nameEn || m.slug]))

    const newFriendItems = recentFriendships.map((f: any) => {
      const isSender = f.senderId === request.userId
      const isMe = isSender || f.receiverId === request.userId
      // When isMe, always put the current user in user1 and the friend in user2
      // so the iOS "Du og @user2 ble venner" string renders correctly.
      const user1 = isMe ? (isSender ? f.sender : f.receiver) : f.sender
      const user2 = isMe ? (isSender ? f.receiver : f.sender) : f.receiver
      return {
        id: `friend-${f.senderId}-${f.receiverId}`,
        type: 'new_friend',
        createdAt: f.createdAt.toISOString(),
        user1: { username: user1.username ?? '?', avatarEmoji: user1.avatarEmoji, avatarUrl: (user1 as any).avatarUrl ?? null },
        user2: { username: user2.username ?? '?', avatarEmoji: user2.avatarEmoji, avatarUrl: (user2 as any).avatarUrl ?? null },
        isMe,
      }
    })

    const streakItems = activeStreaks.map((p: any) => ({
      id: `streak-${p.userId}-${p.mode}`,
      type: 'streak',
      createdAt: p.updatedAt.toISOString(),
      user: { username: p.user.username ?? '?', avatarEmoji: p.user.avatarEmoji, avatarUrl: (p.user as any).avatarUrl ?? null },
      streakCount: p.currentStreak,
      modeName: modeNameMap.get(p.mode) ?? p.mode,
      isMine: p.userId === request.userId,
    }))

    const feed = [...newFriendItems, ...streakItems]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 20)

    return reply.send({ feed })
  })

  // GET /v1/activity/duel-streaks — top ongoing duel streaks per opponent
  app.get('/duel-streaks', auth, async (request: any, reply) => {
    // Find all multiplayer rooms the user participated in, newest first
    const participations = await app.prisma.multiplayerParticipant.findMany({
      where: { userId: request.userId },
      select: { roomId: true },
    })
    const roomIds = participations.map(p => p.roomId)

    const rooms = await app.prisma.multiplayerRoom.findMany({
      where: { id: { in: roomIds }, status: 'finished' },
      orderBy: { updatedAt: 'desc' },
      take: 200,
      include: {
        participants: { select: { userId: true } },
      },
    })

    // Build streak per opponent: consecutive rooms with same opponent, newest first
    const streaks: Map<string, number> = new Map()
    const active: Map<string, boolean> = new Map() // whether streak is still unbroken

    for (const room of rooms) {
      const opponentId = room.participants.find(p => p.userId !== request.userId)?.userId
      if (!opponentId) continue
      if (active.get(opponentId) === false) continue // streak already broken for this opponent

      if (active.get(opponentId) === undefined) {
        streaks.set(opponentId, 1)
        active.set(opponentId, true)
      } else {
        streaks.set(opponentId, (streaks.get(opponentId) ?? 0) + 1)
      }
    }

    // Fetch usernames for opponents with streak >= 3
    const eligibleOpponentIds = [...streaks.entries()]
      .filter(([, count]) => count >= 3)
      .map(([id]) => id)

    if (eligibleOpponentIds.length === 0) return reply.send({ streaks: [] })

    const users: any[] = await (app.prisma.user as any).findMany({
      where: { id: { in: eligibleOpponentIds } },
      select: { id: true, username: true, avatarEmoji: true, avatarUrl: true },
    })
    const userMap = new Map(users.map(u => [u.id, u]))

    const result = eligibleOpponentIds
      .map(id => ({
        opponentId: id,
        opponentUsername: userMap.get(id)?.username ?? '?',
        opponentAvatarEmoji: userMap.get(id)?.avatarEmoji ?? '🧠',
        opponentAvatarUrl: (userMap.get(id) as any)?.avatarUrl ?? null,
        streak: streaks.get(id) ?? 0,
      }))
      .sort((a, b) => b.streak - a.streak)
      .slice(0, 5)

    return reply.send({ streaks: result })
  })
}

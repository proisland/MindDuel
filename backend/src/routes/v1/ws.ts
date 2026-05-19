import type { FastifyInstance } from 'fastify'
import type { WebSocket } from '@fastify/websocket'
import { z } from 'zod'
import crypto from 'crypto'
import { sendPush } from '../../lib/apns'

// ── Room state (stored in Redis with TTL) ─────────────────────────────────────

const ROOM_TTL = 60 * 60 * 48 // 48 hours
const DISCONNECT_GRACE_MS = 15_000
const LOCK_TTL_MS = 500
const LOCK_RETRIES = 3
const LOCK_RETRY_DELAY_MS = 50

interface Participant {
  userId: string
  username: string
  avatarEmoji: string
  avatarUrl: string | null
  lives: number
  skips: number
  isActive: boolean
  score: number
}

interface RoomState {
  id: string
  code: string
  mode: string
  startLevel: number
  hostUserId: string
  participants: Participant[]
  turnIndex: number
  status: 'waiting' | 'active' | 'finished'
  name: string
  questionsPerRound: number
  currentTurnQuestionsAnswered: number
  currentRoundIndex: number
  turnNotifiedAt: number | null
  roundTurnCompletions: string[]
}

interface PubSubEnvelope {
  payload: object
  excludeUserId?: string
  targetUserId?: string
}

type RedisClient = FastifyInstance['redis']

// In-process map of connected WebSockets per room (local to this instance)
const connections = new Map<string, Map<string, WebSocket>>() // roomId → userId → ws

export function activeConnectionCount(): number {
  let n = 0
  for (const room of connections.values()) n += room.size
  return n
}

function roomKey(roomId: string) { return `room:${roomId}` }
function lockKey(roomId: string) { return `room:${roomId}:lock` }
function broadcastChannel(roomId: string) { return `room:${roomId}:broadcast` }

async function getRoomState(redis: RedisClient, roomId: string): Promise<RoomState | null> {
  const raw = await redis.get(roomKey(roomId))
  return raw ? JSON.parse(raw) : null
}

async function setRoomState(redis: RedisClient, state: RoomState) {
  await redis.set(roomKey(state.id), JSON.stringify(state), 'EX', ROOM_TTL)
}

function broadcastLocal(roomId: string, payload: object, excludeUserId?: string) {
  const room = connections.get(roomId)
  if (!room) return
  const msg = JSON.stringify(payload)
  for (const [uid, ws] of room.entries()) {
    if (uid !== excludeUserId && ws.readyState === 1 /* OPEN */) {
      ws.send(msg)
    }
  }
}

function sendToLocal(roomId: string, userId: string, payload: object) {
  const ws = connections.get(roomId)?.get(userId)
  if (ws?.readyState === 1) ws.send(JSON.stringify(payload))
}

async function publish(redis: RedisClient, roomId: string, payload: object, excludeUserId?: string, targetUserId?: string) {
  const envelope: PubSubEnvelope = { payload, excludeUserId, targetUserId }
  await redis.publish(broadcastChannel(roomId), JSON.stringify(envelope))
}

// Atomic lock release: only delete if we still own the lock
const RELEASE_LOCK_SCRIPT = `if redis.call("get",KEYS[1])==ARGV[1] then return redis.call("del",KEYS[1]) else return 0 end`

async function withRoomLock<T>(
  redis: RedisClient,
  roomId: string,
  fn: () => Promise<T>,
): Promise<T | null> {
  const key = lockKey(roomId)
  const token = crypto.randomBytes(8).toString('hex')
  for (let i = 0; i < LOCK_RETRIES; i++) {
    const acquired = await redis.set(key, token, 'PX', LOCK_TTL_MS, 'NX')
    if (acquired) {
      try {
        return await fn()
      } finally {
        await redis.eval(RELEASE_LOCK_SCRIPT, 1, key, token)
      }
    }
    if (i < LOCK_RETRIES - 1) await new Promise(r => setTimeout(r, LOCK_RETRY_DELAY_MS))
  }
  return null
}

// ── Time factor for async turn scoring ───────────────────────────────────────

function computeTimeFactor(elapsedMs: number): number {
  const hours = elapsedMs / (1000 * 60 * 60)
  if (hours <= 1) return 1.0
  if (hours <= 6) return 0.9
  if (hours <= 12) return 0.75
  if (hours <= 24) return 0.6
  if (hours <= 48) return 0.4
  return 0.25
}

// ── HTTP endpoints ────────────────────────────────────────────────────────────

const createRoomBody = z.object({
  mode: z.string().min(1),
  startLevel: z.number().int().min(0).default(0),
  questionsPerRound: z.number().int().min(1).max(10).default(3),
  name: z.string().max(40).default(''),
})

const inviteBody = z.object({ username: z.string().min(1) })

export default async function wsRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // Dedicated subscriber connection for cross-instance broadcast delivery
  const subscriber = app.redis.duplicate()
  await subscriber.psubscribe('room:*:broadcast')
  subscriber.on('pmessage', (_pattern: string, channel: string, message: string) => {
    const roomId = channel.split(':')[1]
    const { payload, excludeUserId, targetUserId } = JSON.parse(message) as PubSubEnvelope
    if (targetUserId) {
      sendToLocal(roomId, targetUserId, payload)
    } else {
      broadcastLocal(roomId, payload, excludeUserId)
    }
  })
  app.addHook('onClose', async () => { await subscriber.quit() })

  // POST /v1/rooms/ws/ticket — issue a one-time WS connection ticket (30 s TTL)
  app.post('/rooms/ws/ticket', auth, async (request, reply) => {
    const ticket = crypto.randomBytes(16).toString('hex')
    await app.redis.set(`ws_ticket:${ticket}`, request.userId, 'EX', 30)
    return reply.status(201).send({ ticket })
  })

  // POST /v1/rooms — create a multiplayer room
  app.post('/rooms', auth, async (request, reply) => {
    const body = createRoomBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const now = new Date()
    const activeMode = await app.prisma.gameMode.findFirst({
      where: {
        slug: body.data.mode,
        isActive: true,
        OR: [{ startsAt: null }, { startsAt: { lte: now } }],
        AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
      },
      select: { id: true },
    })
    if (!activeMode) return reply.status(400).send({ error: 'Mode not available' })

    const user: any = await (app.prisma.user as any).findUnique({
      where: { id: request.userId },
      select: { username: true, avatarEmoji: true, avatarUrl: true },
    })
    if (!user?.username) return reply.status(400).send({ error: 'Username required before playing' })

    const code = crypto.randomBytes(2).toString('hex').toUpperCase()
    const room = await (app.prisma.multiplayerRoom as any).create({
      data: {
        code,
        hostUserId: request.userId,
        mode: body.data.mode,
        startLevel: body.data.startLevel,
        name: body.data.name,
        questionsPerRound: body.data.questionsPerRound,
      },
    })

    const state: RoomState = {
      id: room.id,
      code: room.code,
      mode: room.mode,
      startLevel: room.startLevel,
      hostUserId: request.userId,
      name: body.data.name,
      questionsPerRound: body.data.questionsPerRound,
      participants: [{
        userId: request.userId,
        username: user.username,
        avatarEmoji: user.avatarEmoji,
        avatarUrl: (user as any).avatarUrl ?? null,
        lives: 5,
        skips: 5,
        isActive: true,
        score: 0,
      }],
      turnIndex: 0,
      status: 'waiting',
      currentTurnQuestionsAnswered: 0,
      currentRoundIndex: 1,
      turnNotifiedAt: null,
      roundTurnCompletions: [],
    }
    await setRoomState(app.redis, state)

    return reply.status(201).send({ id: room.id, code: room.code })
  })

  // GET /v1/rooms/:code — look up a room by code
  app.get('/rooms/:code', auth, async (request, reply) => {
    const { code } = request.params as { code: string }
    const room = await (app.prisma.multiplayerRoom as any).findUnique({
      where: { code: code.toUpperCase() },
      select: { id: true, code: true, mode: true, hostUserId: true, status: true, name: true, questionsPerRound: true },
    })
    if (!room) return reply.status(404).send({ error: 'Room not found' })

    const state = await getRoomState(app.redis, room.id)
    return reply.send({
      id: room.id,
      code: room.code,
      mode: room.mode,
      hostId: room.hostUserId,
      name: room.name ?? '',
      questionsPerRound: room.questionsPerRound ?? 3,
      maxPlayers: 10,
      state: room.status,
      participants: state?.participants ?? [],
    })
  })

  // GET /v1/rooms/active — list rooms the authenticated user is participating in (active/waiting)
  app.get('/rooms/active', auth, async (request, reply) => {
    const participations = await app.prisma.multiplayerParticipant.findMany({
      where: { userId: request.userId },
      select: { roomId: true },
    })
    const roomIds = participations.map((p: any) => p.roomId)
    if (roomIds.length === 0) return reply.send({ rooms: [] })

    const rooms = await (app.prisma.multiplayerRoom as any).findMany({
      where: { id: { in: roomIds }, status: { in: ['waiting', 'active'] } },
      orderBy: { updatedAt: 'desc' },
      select: { id: true, code: true, mode: true, hostUserId: true, status: true, name: true, questionsPerRound: true },
    })

    const roomsWithState = await Promise.all(rooms.map(async (room: any) => {
      const state = await getRoomState(app.redis, room.id)
      return {
        id: room.id, code: room.code, mode: room.mode,
        hostId: room.hostUserId, name: room.name ?? '',
        questionsPerRound: room.questionsPerRound ?? 3,
        state: room.status,
        participants: state?.participants ?? [],
        turnIndex: state?.turnIndex ?? 0,
        currentRoundIndex: state?.currentRoundIndex ?? 1,
      }
    }))

    return reply.send({ rooms: roomsWithState })
  })

  // POST /v1/rooms/:roomId/invite — send a push invite to a friend by username
  app.post('/rooms/:roomId/invite', auth, async (request, reply) => {
    const { roomId } = request.params as { roomId: string }
    const body = inviteBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const state = await getRoomState(app.redis, roomId)
    if (!state) return reply.status(404).send({ error: 'Room not found' })
    if (state.hostUserId !== request.userId) return reply.status(403).send({ error: 'Only host can invite' })
    if (state.status !== 'waiting') return reply.status(400).send({ error: 'Game already started' })

    const [invitee, inviter] = await Promise.all([
      app.prisma.user.findUnique({ where: { username: body.data.username }, select: { id: true } }),
      app.prisma.user.findUnique({ where: { id: request.userId }, select: { username: true } }),
    ])
    if (!invitee) return reply.status(404).send({ error: 'User not found' })

    const inviterName = inviter?.username ?? 'Noen'
    app.prisma.pushToken.findMany({ where: { userId: invitee.id } }).then(tokens => {
      tokens.forEach(({ deviceToken }) =>
        sendPush(deviceToken, 'Spillinvitasjon 🎮', `${inviterName} inviterer deg til et spill`, {
          kind: 'multiplayerInvite',
          roomCode: state.code,
          mode: state.mode,
          fromUsername: inviterName,
        }).catch(() => {}),
      )
    }).catch(() => {})

    return reply.status(204).send()
  })

  // DELETE /v1/rooms/:roomId — cancel a waiting room (host only)
  app.delete('/rooms/:roomId', auth, async (request, reply) => {
    const { roomId } = request.params as { roomId: string }
    const state = await getRoomState(app.redis, roomId)
    if (!state) return reply.status(404).send({ error: 'Room not found' })
    if (state.hostUserId !== request.userId) return reply.status(403).send({ error: 'Only host can cancel' })
    if (state.status !== 'waiting') return reply.status(400).send({ error: 'Game already started' })

    await app.redis.del(roomKey(roomId))
    await (app.prisma.multiplayerRoom as any).update({ where: { id: roomId }, data: { status: 'finished' } })
    await publish(app.redis, roomId, { type: 'room_cancelled' })
    return reply.status(204).send()
  })

  // DELETE /v1/rooms/:roomId/players/:userId — host removes a player from waiting lobby
  app.delete('/rooms/:roomId/players/:targetUserId', auth, async (request, reply) => {
    const { roomId, targetUserId } = request.params as { roomId: string; targetUserId: string }
    const state = await getRoomState(app.redis, roomId)
    if (!state) return reply.status(404).send({ error: 'Room not found' })
    if (state.hostUserId !== request.userId) return reply.status(403).send({ error: 'Only host can remove players' })
    if (state.status !== 'waiting') return reply.status(400).send({ error: 'Game already started' })
    if (targetUserId === request.userId) return reply.status(400).send({ error: 'Cannot remove yourself' })

    state.participants = state.participants.filter(p => p.userId !== targetUserId)
    await setRoomState(app.redis, state)
    await publish(app.redis, roomId, { type: 'player_removed', userId: targetUserId })
    sendToLocal(roomId, targetUserId, { type: 'you_were_removed' })
    return reply.status(204).send()
  })

  // WS /v1/rooms/:roomId/ws — real-time game connection
  app.get('/rooms/:roomId/ws', { websocket: true }, async (socket: WebSocket, request) => {
    // Authenticate via one-time ?ticket= query param fetched just before connecting.
    const ticket = (request.query as { ticket?: string }).ticket
    if (!ticket) { socket.close(4001, 'Unauthorized'); return }

    const userId = await app.redis.getdel(`ws_ticket:${ticket}`)
    if (!userId) { socket.close(4001, 'Invalid or expired ticket'); return }

    const user: any = await (app.prisma.user as any).findUnique({
      where: { id: userId },
      select: { isSuspended: true, username: true, avatarEmoji: true, avatarUrl: true },
    })
    if (!user || user.isSuspended || !user.username) {
      socket.close(4003, 'Unauthorized')
      return
    }

    const { roomId } = request.params as { roomId: string }
    const state = await getRoomState(app.redis, roomId)
    if (!state) { socket.close(4004, 'Room not found'); return }

    // Register local connection
    if (!connections.has(roomId)) connections.set(roomId, new Map())
    connections.get(roomId)!.set(userId, socket)

    // Add participant if not already in room
    if (!state.participants.find(p => p.userId === userId)) {
      if (state.participants.length >= 10) { socket.close(4008, 'Room full'); return }
      state.participants.push({
        userId, username: user.username, avatarEmoji: user.avatarEmoji,
        avatarUrl: (user as any).avatarUrl ?? null,
        lives: 5, skips: 5, isActive: true, score: 0,
      })
      await (app.prisma.multiplayerParticipant as any).upsert({
        where: { roomId_userId: { roomId, userId } },
        update: {},
        create: { roomId, userId },
      })
      await setRoomState(app.redis, state)
    } else {
      const p = state.participants.find(p => p.userId === userId)!
      p.isActive = true
      await app.redis.del(`disconnect:${roomId}:${userId}`)
      await setRoomState(app.redis, state)
    }

    socket.send(JSON.stringify({ type: 'room_state', state }))
    await publish(app.redis, roomId, { type: 'player_joined', userId, participants: state.participants }, userId)

    // ── Incoming messages ──────────────────────────────────────────────────────
    socket.on('message', async (raw: Buffer | string) => {
      let msg: { type: string; [k: string]: unknown }
      try { msg = JSON.parse(raw.toString()) } catch { return }

      switch (msg.type) {
        case 'start_game': {
          await withRoomLock(app.redis, roomId, async () => {
            const s = await getRoomState(app.redis, roomId)
            if (!s) return
            if (userId !== s.hostUserId) return
            if (s.status !== 'waiting') return
            if (s.participants.filter(p => p.isActive).length < 2) return

            // Apply any settings sent with the start message
            if (typeof msg.name === 'string') s.name = String(msg.name).slice(0, 40)
            if (typeof msg.questionsPerRound === 'number') {
              s.questionsPerRound = Math.min(10, Math.max(1, Number(msg.questionsPerRound)))
            }
            if (typeof msg.mode === 'string') s.mode = String(msg.mode)
            if (typeof msg.startLevel === 'number') s.startLevel = Number(msg.startLevel)

            s.status = 'active'
            s.currentRoundIndex = 1
            s.roundTurnCompletions = [] as string[]
            s.currentTurnQuestionsAnswered = 0
            s.turnNotifiedAt = Date.now()

            await setRoomState(app.redis, s)

            // Update DB with final settings
            await (app.prisma.multiplayerRoom as any).update({
              where: { id: roomId },
              data: { status: 'active', name: s.name, questionsPerRound: s.questionsPerRound, mode: s.mode, startLevel: s.startLevel },
            })

            await publish(app.redis, roomId, { type: 'game_started', state: s })
            await notifyTurnWithPush(app, roomId, s)
          })
          break
        }

        case 'submit_answer': {
          await withRoomLock(app.redis, roomId, async () => {
            const s = await getRoomState(app.redis, roomId)
            if (!s) return
            const active = s.participants[s.turnIndex]
            if (active?.userId !== userId) return
            if (s.status !== 'active') return

            const { questionRef, userAnswer, answerTimeMs, clientReportsCorrect } = msg as unknown as {
              questionRef: string; userAnswer: string; answerTimeMs: number; clientReportsCorrect: boolean
            }

            if (typeof answerTimeMs === 'number' && answerTimeMs < 200) return

            let isCorrect = typeof clientReportsCorrect === 'boolean' ? clientReportsCorrect : false
            if (s.mode === 'pi') {
              const { validatePiAnswer } = await import('../../lib/pi')
              isCorrect = validatePiAnswer(parseInt(questionRef, 10), String(userAnswer))
            }

            let scoreGained = 0
            if (isCorrect) {
              const answerTimeSec = Math.max(0.5, (answerTimeMs ?? 1000) / 1000)
              scoreGained = Math.round(50 / answerTimeSec)
              active.score += scoreGained
            } else {
              active.lives = Math.max(0, active.lives - 1)
            }

            await publish(app.redis, roomId, {
              type: 'answer_result',
              userId,
              isCorrect,
              lives: active.lives,
              scoreGained,
              totalScore: active.score,
            })

            const playerEliminated = active.lives === 0
            if (playerEliminated) {
              active.isActive = false
              await publish(app.redis, roomId, { type: 'player_out', userId })
            }

            s.currentTurnQuestionsAnswered = (s.currentTurnQuestionsAnswered ?? 0) + 1
            const questionsPerRound = s.questionsPerRound ?? 3
            const shouldAdvanceTurn = playerEliminated || s.currentTurnQuestionsAnswered >= questionsPerRound

            if (shouldAdvanceTurn) {
              // Apply time factor to this turn's accumulated score
              if (s.turnNotifiedAt) {
                const elapsedMs = Date.now() - s.turnNotifiedAt
                const timeFactor = computeTimeFactor(elapsedMs)
                if (timeFactor < 1.0 && scoreGained > 0) {
                  // Adjust score: recompute turn total with factor applied
                  // For simplicity, apply factor to the score gained this turn
                  // A full implementation would track per-turn accumulated score
                  const adjustedGain = Math.floor(scoreGained * timeFactor) - scoreGained
                  active.score = Math.max(0, active.score + adjustedGain)
                  await publish(app.redis, roomId, {
                    type: 'turn_time_factor',
                    userId,
                    timeFactor,
                    totalScore: active.score,
                  })
                }
              }

              // Mark player as having completed their turn this round
              if (!s.roundTurnCompletions) s.roundTurnCompletions = [] as string[]
              if (!s.roundTurnCompletions.includes(userId)) {
                s.roundTurnCompletions.push(userId)
              }

              s.currentTurnQuestionsAnswered = 0
              advanceTurn(s)

              await setRoomState(app.redis, s)

              const remaining = s.participants.filter(p => p.isActive)
              if (remaining.length <= 1) {
                s.status = 'finished'
                await setRoomState(app.redis, s)
                const winner = remaining[0] ?? null
                await publish(app.redis, roomId, {
                  type: 'game_over',
                  winner: winner?.userId ?? null,
                  participants: s.participants,
                })
                // Update DB
                await (app.prisma.multiplayerRoom as any).update({
                  where: { id: roomId },
                  data: { status: 'finished' },
                })
                // Notify all participants
                for (const p of s.participants) {
                  sendPushToUser(app, p.userId,
                    '🏆 Spillet er ferdig!',
                    winner ? `${winner.username} vant!` : 'Spillet er over',
                    { kind: 'gameOver', roomId },
                  )
                }
              } else {
                // Check if round complete (all currently active players have had their turn)
                const allHadTurn = remaining.every(p => s.roundTurnCompletions?.includes(p.userId))
                if (allHadTurn) {
                  const roundIdx = s.currentRoundIndex
                  s.currentRoundIndex = (s.currentRoundIndex ?? 1) + 1
                  s.roundTurnCompletions = [] as string[]
                  await setRoomState(app.redis, s)
                  await publish(app.redis, roomId, {
                    type: 'round_summary',
                    roundIndex: roundIdx,
                    participants: s.participants,
                  })
                }

                s.turnNotifiedAt = Date.now()
                await setRoomState(app.redis, s)
                await notifyTurnWithPush(app, roomId, s)
              }
            } else {
              await setRoomState(app.redis, s)
            }
          })
          break
        }

        case 'use_skip': {
          await withRoomLock(app.redis, roomId, async () => {
            const s = await getRoomState(app.redis, roomId)
            if (!s) return
            const active = s.participants[s.turnIndex]
            if (active?.userId !== userId) return
            if (s.status !== 'active') return

            active.skips = Math.max(0, active.skips - 1)
            await publish(app.redis, roomId, { type: 'skip_used', userId, skips: active.skips })

            s.currentTurnQuestionsAnswered = (s.currentTurnQuestionsAnswered ?? 0) + 1
            const questionsPerRound = s.questionsPerRound ?? 3
            const playerEliminated = active.skips === 0
            const shouldAdvanceTurn = playerEliminated || s.currentTurnQuestionsAnswered >= questionsPerRound

            if (playerEliminated) {
              active.isActive = false
              await publish(app.redis, roomId, { type: 'player_out', userId })
            }

            if (shouldAdvanceTurn) {
              if (!s.roundTurnCompletions) s.roundTurnCompletions = [] as string[]
              if (!s.roundTurnCompletions.includes(userId)) s.roundTurnCompletions.push(userId)
              s.currentTurnQuestionsAnswered = 0
              advanceTurn(s)
              await setRoomState(app.redis, s)

              const remaining = s.participants.filter(p => p.isActive)
              if (remaining.length <= 1) {
                s.status = 'finished'
                await setRoomState(app.redis, s)
                const winner = remaining[0] ?? null
                await publish(app.redis, roomId, {
                  type: 'game_over',
                  winner: winner?.userId ?? null,
                  participants: s.participants,
                })
                await (app.prisma.multiplayerRoom as any).update({
                  where: { id: roomId },
                  data: { status: 'finished' },
                })
                for (const p of s.participants) {
                  sendPushToUser(app, p.userId,
                    '🏆 Spillet er ferdig!',
                    winner ? `${winner.username} vant!` : 'Spillet er over',
                    { kind: 'gameOver', roomId },
                  )
                }
              } else {
                const allHadTurn = remaining.every(p => s.roundTurnCompletions?.includes(p.userId))
                if (allHadTurn) {
                  const roundIdx = s.currentRoundIndex
                  s.currentRoundIndex = (s.currentRoundIndex ?? 1) + 1
                  s.roundTurnCompletions = [] as string[]
                  await setRoomState(app.redis, s)
                  await publish(app.redis, roomId, {
                    type: 'round_summary',
                    roundIndex: roundIdx,
                    participants: s.participants,
                  })
                }
                s.turnNotifiedAt = Date.now()
                await setRoomState(app.redis, s)
                await notifyTurnWithPush(app, roomId, s)
              }
            } else {
              await setRoomState(app.redis, s)
              await notifyTurnWithPush(app, roomId, s)
            }
          })
          break
        }
      }
    })

    // ── Disconnect handling ────────────────────────────────────────────────────
    socket.on('close', async () => {
      connections.get(roomId)?.delete(userId)
      await app.redis.set(`disconnect:${roomId}:${userId}`, '1', 'PX', DISCONNECT_GRACE_MS + 5000)

      setTimeout(async () => {
        if (connections.get(roomId)?.has(userId)) return
        const stillDisconnected = await app.redis.exists(`disconnect:${roomId}:${userId}`)
        if (!stillDisconnected) return

        await withRoomLock(app.redis, roomId, async () => {
          const s = await getRoomState(app.redis, roomId)
          if (!s) return

          const p = s.participants.find(p => p.userId === userId)
          if (!p) return

          p.isActive = false
          await app.redis.del(`disconnect:${roomId}:${userId}`)
          await publish(app.redis, roomId, { type: 'player_disconnected', userId })
          advanceTurn(s)
          await setRoomState(app.redis, s)

          const remaining = s.participants.filter(p => p.isActive)
          if (s.status === 'active' && remaining.length <= 1) {
            s.status = 'finished'
            await setRoomState(app.redis, s)
            await publish(app.redis, roomId, { type: 'game_over', winner: remaining[0]?.userId ?? null, participants: s.participants })
          }
        })
      }, DISCONNECT_GRACE_MS)
    })
  })
}

function advanceTurn(state: RoomState) {
  const active = state.participants.filter(p => p.isActive)
  if (active.length === 0) return
  let next = (state.turnIndex + 1) % state.participants.length
  let safety = 0
  while (!state.participants[next].isActive && safety < state.participants.length) {
    next = (next + 1) % state.participants.length
    safety++
  }
  state.turnIndex = next
}

async function notifyTurnWithPush(app: FastifyInstance, roomId: string, state: RoomState) {
  const current = state.participants[state.turnIndex]
  if (!current) return
  await publish(app.redis, roomId, {
    type: 'turn_changed',
    activeUserId: current.userId,
    turnIndex: state.turnIndex,
  })
  await publish(app.redis, roomId, { type: 'your_turn' }, undefined, current.userId)
  sendPushToUser(app, current.userId, '🎮 Din tur!', `Det er din tur i ${state.name || 'spillet'}`, {
    kind: 'yourTurn',
    roomId,
    roomCode: state.code,
  })
}

function sendPushToUser(app: FastifyInstance, userId: string, title: string, body: string, data: Record<string, string>) {
  app.prisma.pushToken.findMany({ where: { userId } }).then(tokens => {
    tokens.forEach(({ deviceToken }) =>
      sendPush(deviceToken, title, body, data).catch(() => {}),
    )
  }).catch(() => {})
}

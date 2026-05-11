import type { FastifyInstance } from 'fastify'
import type { WebSocket } from '@fastify/websocket'
import { z } from 'zod'
import crypto from 'crypto'

// ── Room state (stored in Redis with TTL) ─────────────────────────────────────

const ROOM_TTL = 60 * 60 * 4 // 4 hours
const DISCONNECT_GRACE_MS = 15_000

interface Participant {
  userId: string
  username: string
  avatarEmoji: string
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
}

// In-process map of connected WebSockets per room
const connections = new Map<string, Map<string, WebSocket>>() // roomId → userId → ws

function roomKey(roomId: string) { return `room:${roomId}` }

async function getRoomState(redis: FastifyInstance['redis'], roomId: string): Promise<RoomState | null> {
  const raw = await redis.get(roomKey(roomId))
  return raw ? JSON.parse(raw) : null
}

async function setRoomState(redis: FastifyInstance['redis'], state: RoomState) {
  await redis.set(roomKey(state.id), JSON.stringify(state), 'EX', ROOM_TTL)
}

function broadcast(roomId: string, payload: object, excludeUserId?: string) {
  const room = connections.get(roomId)
  if (!room) return
  const msg = JSON.stringify(payload)
  for (const [uid, ws] of room.entries()) {
    if (uid !== excludeUserId && ws.readyState === 1 /* OPEN */) {
      ws.send(msg)
    }
  }
}

function sendTo(roomId: string, userId: string, payload: object) {
  const ws = connections.get(roomId)?.get(userId)
  if (ws?.readyState === 1) ws.send(JSON.stringify(payload))
}

// ── HTTP endpoints ────────────────────────────────────────────────────────────

const createRoomBody = z.object({
  mode: z.string().min(1),
  startLevel: z.number().int().min(0).default(0),
})

export default async function wsRoutes(app: FastifyInstance) {
  const auth = { onRequest: [app.authenticate] }

  // POST /v1/rooms — create a multiplayer room
  app.post('/rooms', auth, async (request, reply) => {
    const body = createRoomBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    const user = await app.prisma.user.findUnique({
      where: { id: request.userId },
      select: { username: true, avatarEmoji: true },
    })
    if (!user?.username) return reply.status(400).send({ error: 'Username required before playing' })

    const code = crypto.randomBytes(2).toString('hex').toUpperCase()
    const room = await app.prisma.multiplayerRoom.create({
      data: {
        code,
        hostUserId: request.userId,
        mode: body.data.mode,
        startLevel: body.data.startLevel,
      },
    })

    const state: RoomState = {
      id: room.id,
      code: room.code,
      mode: room.mode,
      startLevel: room.startLevel,
      hostUserId: request.userId,
      participants: [{
        userId: request.userId,
        username: user.username,
        avatarEmoji: user.avatarEmoji,
        lives: 5,
        skips: 5,
        isActive: true,
        score: 0,
      }],
      turnIndex: 0,
      status: 'waiting',
    }
    await setRoomState(app.redis, state)

    return reply.status(201).send({ roomId: room.id, code: room.code })
  })

  // GET /v1/rooms/:code — look up a room by code
  app.get('/rooms/:code', auth, async (request, reply) => {
    const { code } = request.params as { code: string }
    const room = await app.prisma.multiplayerRoom.findUnique({
      where: { code: code.toUpperCase() },
      select: { id: true, code: true, mode: true, startLevel: true, hostUserId: true, status: true },
    })
    if (!room) return reply.status(404).send({ error: 'Room not found' })

    const state = await getRoomState(app.redis, room.id)
    return reply.send({ ...room, participants: state?.participants ?? [] })
  })

  // WS /v1/rooms/:roomId/ws — real-time game connection
  app.get('/rooms/:roomId/ws', { websocket: true }, async (socket: WebSocket, request) => {
    // Authenticate via ?token= query param (JWT cannot be sent in WS headers from iOS)
    const token = (request.query as { token?: string }).token
    if (!token) { socket.close(4001, 'Unauthorized'); return }

    let userId: string
    try {
      const payload = app.jwt.verify(token) as { sub: string }
      userId = payload.sub
    } catch {
      socket.close(4001, 'Invalid token'); return
    }

    const { roomId } = request.params as { roomId: string }
    const state = await getRoomState(app.redis, roomId)
    if (!state) { socket.close(4004, 'Room not found'); return }

    // Register connection
    if (!connections.has(roomId)) connections.set(roomId, new Map())
    connections.get(roomId)!.set(userId, socket)

    // Add participant if not already in room
    if (!state.participants.find(p => p.userId === userId)) {
      if (state.participants.length >= 8) { socket.close(4008, 'Room full'); return }
      const user = await app.prisma.user.findUnique({
        where: { id: userId },
        select: { username: true, avatarEmoji: true },
      })
      if (!user?.username) { socket.close(4003, 'Username required'); return }
      state.participants.push({
        userId, username: user.username, avatarEmoji: user.avatarEmoji,
        lives: 5, skips: 5, isActive: true, score: 0,
      })
      await setRoomState(app.redis, state)
    } else {
      const p = state.participants.find(p => p.userId === userId)!
      p.isActive = true
      await setRoomState(app.redis, state)
    }

    socket.send(JSON.stringify({ type: 'room_state', state }))
    broadcast(roomId, { type: 'player_joined', userId, participants: state.participants }, userId)

    // ── Incoming messages ──────────────────────────────────────────────────────
    socket.on('message', async (raw: Buffer | string) => {
      let msg: { type: string; [k: string]: unknown }
      try { msg = JSON.parse(raw.toString()) } catch { return }

      const currentState = await getRoomState(app.redis, roomId)
      if (!currentState) return

      switch (msg.type) {
        case 'start_game': {
          if (userId !== currentState.hostUserId) break
          if (currentState.status !== 'waiting') break
          currentState.status = 'active'
          await setRoomState(app.redis, currentState)
          broadcast(roomId, { type: 'game_started', state: currentState })
          notifyTurn(roomId, currentState)
          break
        }

        case 'submit_answer': {
          const active = currentState.participants[currentState.turnIndex]
          if (active?.userId !== userId) break
          if (currentState.status !== 'active') break

          const { questionRef, userAnswer, answerTimeMs } = msg as unknown as {
            questionRef: string; userAnswer: string; answerTimeMs: number
          }

          // Basic validation
          if (typeof answerTimeMs === 'number' && answerTimeMs < 200) break

          let isCorrect = false
          if (currentState.mode === 'pi') {
            const { validatePiAnswer } = await import('../../lib/pi')
            isCorrect = validatePiAnswer(parseInt(questionRef, 10), String(userAnswer))
          }
          // Knowledge mode validation omitted here; extend similarly to games.ts

          if (!isCorrect) {
            active.lives = Math.max(0, active.lives - 1)
          }

          broadcast(roomId, { type: 'answer_result', userId, isCorrect, lives: active.lives })

          if (active.lives === 0 || active.skips === 0) {
            active.isActive = false
            broadcast(roomId, { type: 'player_out', userId })
          }

          advanceTurn(currentState)
          await setRoomState(app.redis, currentState)

          const remaining = currentState.participants.filter(p => p.isActive)
          if (remaining.length <= 1) {
            currentState.status = 'finished'
            await setRoomState(app.redis, currentState)
            const winner = remaining[0] ?? null
            broadcast(roomId, { type: 'game_over', winner: winner?.userId ?? null, participants: currentState.participants })
          } else {
            notifyTurn(roomId, currentState)
          }
          break
        }

        case 'use_skip': {
          const active = currentState.participants[currentState.turnIndex]
          if (active?.userId !== userId) break
          active.skips = Math.max(0, active.skips - 1)
          broadcast(roomId, { type: 'skip_used', userId, skips: active.skips })
          if (active.skips === 0) {
            active.isActive = false
            broadcast(roomId, { type: 'player_out', userId })
            advanceTurn(currentState)
          }
          await setRoomState(app.redis, currentState)
          notifyTurn(roomId, currentState)
          break
        }
      }
    })

    // ── Disconnect handling ────────────────────────────────────────────────────
    socket.on('close', async () => {
      connections.get(roomId)?.delete(userId)

      // Grace period: wait before treating as left
      setTimeout(async () => {
        if (connections.get(roomId)?.has(userId)) return // reconnected

        const s = await getRoomState(app.redis, roomId)
        if (!s) return

        const p = s.participants.find(p => p.userId === userId)
        if (p) {
          p.isActive = false
          broadcast(roomId, { type: 'player_disconnected', userId })
          advanceTurn(s)
          await setRoomState(app.redis, s)

          const remaining = s.participants.filter(p => p.isActive)
          if (s.status === 'active' && remaining.length <= 1) {
            s.status = 'finished'
            await setRoomState(app.redis, s)
            broadcast(roomId, { type: 'game_over', winner: remaining[0]?.userId ?? null, participants: s.participants })
          }
        }
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

function notifyTurn(roomId: string, state: RoomState) {
  const current = state.participants[state.turnIndex]
  if (!current) return
  broadcast(roomId, {
    type: 'turn_changed',
    activeUserId: current.userId,
    turnIndex: state.turnIndex,
  })
  sendTo(roomId, current.userId, { type: 'your_turn', position: current.userId })
}

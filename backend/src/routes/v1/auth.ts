import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { verifyAppleIdToken } from '../../lib/apple'
import { generateRefreshToken, storeRefreshToken, consumeRefreshToken } from '../../lib/tokens'
import { config } from '../../config'

const appleSignInBody = z.object({
  identityToken: z.string().min(1),
  locale: z.string().max(20).optional(),
  // Optional fields sent only on first sign-in by Apple
  email: z.string().email().optional(),
  fullName: z.object({
    givenName: z.string().optional(),
    familyName: z.string().optional(),
  }).optional(),
})

const refreshBody = z.object({
  refreshToken: z.string().min(1),
})

function userResponse(user: {
  id: string
  username: string | null
  avatarEmoji: string
  isPremium: boolean
  isFlagged: boolean
  isSuspended: boolean
  createdAt: Date
}) {
  return {
    id: user.id,
    username: user.username,
    avatarEmoji: user.avatarEmoji,
    isPremium: user.isPremium,
    isFlagged: user.isFlagged,
    isSuspended: user.isSuspended,
    createdAt: user.createdAt.toISOString(),
  }
}

export default async function authRoutes(app: FastifyInstance) {
  // POST /v1/auth/apple
  app.post('/apple', async (request, reply) => {
    const body = appleSignInBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid request body', details: body.error.flatten() })
    }

    let applePayload
    try {
      applePayload = await verifyAppleIdToken(body.data.identityToken, config.apple.clientId)
    } catch (err) {
      app.log.warn({ err }, 'Apple token verification failed')
      return reply.status(401).send({ error: 'Invalid Apple identity token' })
    }

    // Upsert user
    let user = await app.prisma.user.findUnique({
      where: { appleUserId: applePayload.appleUserId },
    })

    if (!user) {
      user = await app.prisma.user.create({
        data: {
          appleUserId: applePayload.appleUserId,
          locale:       body.data.locale ?? null,
          lastActiveAt: new Date(),
        },
      })
    } else {
      await app.prisma.user.update({
        where: { id: user.id },
        data: {
          lastActiveAt: new Date(),
          ...(body.data.locale && { locale: body.data.locale }),
        },
      })
    }

    if (user.isSuspended) {
      return reply.status(403).send({ error: 'Account suspended' })
    }

    const accessToken = app.jwt.sign(
      { sub: user.id },
      { expiresIn: config.jwt.accessTtlSeconds },
    )
    const refreshToken = generateRefreshToken()
    await storeRefreshToken(app.redis, user.id, refreshToken)

    return reply.send({
      accessToken,
      refreshToken,
      needsUsername: !user.username,
      user: userResponse(user),
    })
  })

  // POST /v1/auth/refresh
  app.post('/refresh', async (request, reply) => {
    const body = refreshBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid request body' })
    }

    const userId = await consumeRefreshToken(app.redis, body.data.refreshToken)
    if (!userId) {
      return reply.status(401).send({ error: 'Invalid or expired refresh token' })
    }

    const user = await app.prisma.user.findUnique({ where: { id: userId } })
    if (!user || user.isSuspended) {
      return reply.status(401).send({ error: 'User not found or suspended' })
    }

    const accessToken = app.jwt.sign(
      { sub: user.id },
      { expiresIn: config.jwt.accessTtlSeconds },
    )
    const newRefreshToken = generateRefreshToken()
    await storeRefreshToken(app.redis, user.id, newRefreshToken)

    return reply.send({
      accessToken,
      refreshToken: newRefreshToken,
      user: userResponse(user),
    })
  })

  // POST /v1/auth/dev  — development only, bypasses Apple verification
  if (config.nodeEnv === 'development') {
    const devBody = z.object({ username: z.string().min(1) })
    app.post('/dev', async (request, reply) => {
      const body = devBody.safeParse(request.body)
      if (!body.success) return reply.status(400).send({ error: 'username required' })

      const fakeAppleId = `dev-${body.data.username}`
      let user = await app.prisma.user.findFirst({ where: { appleUserId: fakeAppleId } })
      if (!user) {
        user = await app.prisma.user.create({
          data: { appleUserId: fakeAppleId, username: body.data.username, lastActiveAt: new Date() },
        })
      } else {
        await app.prisma.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } })
      }

      const accessToken = app.jwt.sign({ sub: user.id }, { expiresIn: config.jwt.accessTtlSeconds })
      const refreshToken = generateRefreshToken()
      await storeRefreshToken(app.redis, user.id, refreshToken)
      return reply.send({ accessToken, refreshToken, needsUsername: !user.username, user: userResponse(user) })
    })
  }

  // POST /v1/auth/logout
  app.post('/logout', { onRequest: [app.authenticate] }, async (request, reply) => {
    const body = refreshBody.safeParse(request.body)
    if (body.success) {
      await consumeRefreshToken(app.redis, body.data.refreshToken)
    }
    return reply.status(204).send()
  })
}

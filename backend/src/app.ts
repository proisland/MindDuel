import Fastify from 'fastify'
import fastifyJwt from '@fastify/jwt'
import fastifyCors from '@fastify/cors'
import fastifyRateLimit from '@fastify/rate-limit'
import fastifySensible from '@fastify/sensible'
import fastifyView from '@fastify/view'
import fastifyStatic from '@fastify/static'
import fastifyFormbody from '@fastify/formbody'
import fastifyCookie from '@fastify/cookie'
import ejs from 'ejs'
import path from 'path'

import { config } from './config'
import dbPlugin from './plugins/db'
import redisPlugin from './plugins/redis'
import s3Plugin from './plugins/s3'
import v1Routes from './routes/v1/index'
import adminRoutes from './routes/admin/index'

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: config.isDev ? 'debug' : 'info',
      transport: config.isDev
        ? { target: 'pino-pretty', options: { colorize: true } }
        : undefined,
    },
  })

  // ── Core plugins ────────────────────────────────────────────────────────────
  await app.register(fastifySensible)
  await app.register(fastifyFormbody)
  await app.register(fastifyCookie, { secret: config.admin.sessionSecret })
  await app.register(fastifyCors, { origin: config.isDev ? true : false })

  await app.register(fastifyRateLimit, {
    max: 120,
    timeWindow: '1 minute',
    keyGenerator: (req) => req.headers['x-forwarded-for']?.toString() ?? req.ip,
  })

  await app.register(fastifyJwt, {
    secret: config.jwt.secret,
    sign: { algorithm: 'HS256' },
  })

  // ── Infrastructure plugins ──────────────────────────────────────────────────
  await app.register(dbPlugin)
  await app.register(redisPlugin)
  await app.register(s3Plugin)

  // ── Auth decorator ──────────────────────────────────────────────────────────
  app.decorate('authenticate', async (request: any, reply: any) => {
    try {
      await request.jwtVerify()
      request.userId = (request.user as { sub: string }).sub
    } catch {
      reply.status(401).send({ error: 'Unauthorized' })
    }
  })

  // ── Views (admin) ───────────────────────────────────────────────────────────
  await app.register(fastifyView, {
    engine: { ejs },
    root: path.join(__dirname, '..', 'views'),
    layout: 'layout.ejs',
    viewExt: 'ejs',
  })

  await app.register(fastifyStatic, {
    root: path.join(__dirname, '..', 'public'),
    prefix: '/public/',
  })

  // ── Routes ──────────────────────────────────────────────────────────────────
  await app.register(v1Routes,    { prefix: '/v1' })
  await app.register(adminRoutes, { prefix: '/admin' })

  // Root redirect to admin
  app.get('/', async (_req, reply) => reply.redirect('/admin'))

  return app
}

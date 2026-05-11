import type { FastifyInstance } from 'fastify'
import authRoutes from './auth'
import meRoutes from './me'

export default async function v1Routes(app: FastifyInstance) {
  app.register(authRoutes, { prefix: '/auth' })
  app.register(meRoutes,   { prefix: '/me' })

  // Health / version
  app.get('/health', async (_request, reply) => {
    return reply.send({ status: 'ok', version: 1 })
  })
}

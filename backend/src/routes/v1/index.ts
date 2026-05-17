import type { FastifyInstance } from 'fastify'
import authRoutes from './auth'
import meRoutes from './me'
import gamesRoutes from './games'
import modesRoutes from './modes'
import questionsRoutes from './questions'
import friendsRoutes from './friends'
import scoreboardRoutes from './scoreboard'
import telemetryRoutes from './telemetry'
import feedbackRoutes from './feedback'
import wsRoutes from './ws'
import challengesRoutes from './challenges'
import activityRoutes from './activity'
import usersRoutes from './users'

export default async function v1Routes(app: FastifyInstance) {
  app.register(authRoutes,       { prefix: '/auth' })
  app.register(meRoutes,         { prefix: '/me' })
  app.register(gamesRoutes,      { prefix: '/games' })
  app.register(modesRoutes,      { prefix: '/modes' })
  app.register(questionsRoutes,  { prefix: '/questions' })
  app.register(friendsRoutes,    { prefix: '/friends' })
  app.register(scoreboardRoutes, { prefix: '/scoreboard' })
  app.register(telemetryRoutes,  { prefix: '/telemetry' })
  app.register(feedbackRoutes,   { prefix: '/feedback' })
  app.register(challengesRoutes, { prefix: '/challenges' })
  app.register(activityRoutes,   { prefix: '/activity' })
  app.register(usersRoutes,      { prefix: '/users' })
  app.register(wsRoutes)         // registers /rooms/* and /rooms/:id/ws

  app.get('/health', async (_request, reply) =>
    reply.send({ status: 'ok', version: 1 }),
  )
}

import fp from 'fastify-plugin'
import { PrismaClient } from '@prisma/client'
import type { FastifyInstance } from 'fastify'
import { runStartupMigrations } from '../lib/migrate'

export default fp(async (app: FastifyInstance) => {
  const prisma = new PrismaClient({
    log: app.log.level === 'debug' ? ['query', 'error'] : ['error'],
  })

  await prisma.$connect()
  await runStartupMigrations(prisma)

  app.decorate('prisma', prisma)

  app.addHook('onClose', async () => {
    await prisma.$disconnect()
  })
})

import type { FastifyInstance } from 'fastify'
import bcrypt from 'bcryptjs'
import { z } from 'zod'

const SESSION_KEY = 'admin_session'
const SESSION_TTL = 60 * 60 * 8 // 8 hours

const loginBody = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
})

function requireAdmin(app: FastifyInstance) {
  return async (request: any, reply: any) => {
    const token = request.cookies?.[SESSION_KEY]
    if (!token) return reply.redirect('/admin/login')
    const userId = await app.redis.get(`admin_session:${token}`)
    if (!userId) return reply.redirect('/admin/login')
    request.adminUserId = userId
  }
}

export default async function adminRoutes(app: FastifyInstance) {
  const guard = { onRequest: [requireAdmin(app)] }

  // Login page
  app.get('/login', async (_request, reply) => {
    return reply.view('admin/login.ejs', {})
  })

  // Login submit
  app.post('/login', async (request, reply) => {
    const body = loginBody.safeParse(request.body)
    if (!body.success) {
      return reply.view('admin/login.ejs', { error: 'Invalid form' })
    }

    const admin = await app.prisma.adminUser.findUnique({
      where: { username: body.data.username },
    })

    const valid = admin && await bcrypt.compare(body.data.password, admin.passwordHash)
    if (!valid) {
      return reply.view('admin/login.ejs', { error: 'Invalid credentials' })
    }

    const token = require('crypto').randomBytes(32).toString('hex')
    await app.redis.set(`admin_session:${token}`, admin.id, 'EX', SESSION_TTL)
    reply.setCookie(SESSION_KEY, token, { httpOnly: true, path: '/', maxAge: SESSION_TTL })
    return reply.redirect('/admin')
  })

  // Logout
  app.get('/logout', async (request: any, reply) => {
    const token = request.cookies?.[SESSION_KEY]
    if (token) await app.redis.del(`admin_session:${token}`)
    reply.clearCookie(SESSION_KEY)
    return reply.redirect('/admin/login')
  })

  // Dashboard
  app.get('/', guard, async (_request, reply) => {
    const [totalUsers, activeToday, flaggedUsers, totalRounds, openFeedback, modes] = await Promise.all([
      app.prisma.user.count(),
      app.prisma.user.count({
        where: { lastActiveAt: { gte: new Date(Date.now() - 86_400_000) } },
      }),
      app.prisma.user.count({ where: { isFlagged: true } }),
      app.prisma.gameSession.count(),
      app.prisma.feedback.count({ where: { status: 'open' } }),
      app.prisma.gameMode.findMany({ orderBy: { sortOrder: 'asc' } }),
    ])

    return reply.view('admin/dashboard.ejs', {
      title: 'Dashboard',
      stats: { totalUsers, activeToday, flaggedUsers, totalRounds, openFeedback },
      modes,
    })
  })
}

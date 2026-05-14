import type { FastifyInstance } from 'fastify'
import bcrypt from 'bcryptjs'
import crypto from 'crypto'
import { z } from 'zod'
import adminUsersRoutes from './users'
import adminQuestionsRoutes from './questions'
import adminModesRoutes from './modes'
import adminFeedbackRoutes from './feedback'
import adminStatsRoutes from './stats'

const SESSION_KEY = 'admin_session'
const SESSION_TTL = 60 * 60 * 8

const loginBody = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
})

export function requireAdmin(app: FastifyInstance) {
  return async (request: any, reply: any) => {
    const raw = request.cookies?.[SESSION_KEY]
    if (!raw) return reply.redirect('/admin/login')
    const unsigned = request.unsignCookie(raw)
    if (!unsigned.valid || !unsigned.value) return reply.redirect('/admin/login')
    const adminId = await app.redis.get(`admin_session:${unsigned.value}`)
    if (!adminId) return reply.redirect('/admin/login')
    request.adminId = adminId
  }
}

export default async function adminRoutes(app: FastifyInstance) {
  const guard = { onRequest: [requireAdmin(app)] }

  // ── Auth ───────────────────────────────────────────────────────────────────
  const loginView = (reply: any, data: object = {}) =>
    reply.view('admin/login.ejs', data, { layout: false })

  app.get('/login', async (_req, reply) => loginView(reply))

  app.post('/login', async (request, reply) => {
    const body = loginBody.safeParse(request.body)
    if (!body.success) return loginView(reply, { error: 'Invalid form' })

    const admin = await app.prisma.adminUser.findUnique({ where: { username: body.data.username } })
    const valid = admin && await bcrypt.compare(body.data.password, admin.passwordHash)
    if (!valid) return loginView(reply, { error: 'Invalid credentials' })

    const token = crypto.randomBytes(32).toString('hex')
    await app.redis.set(`admin_session:${token}`, admin.id, 'EX', SESSION_TTL)
    reply.setCookie(SESSION_KEY, token, { httpOnly: true, path: '/admin', maxAge: SESSION_TTL, signed: true })
    return reply.redirect('/admin')
  })

  app.get('/logout', async (request: any, reply) => {
    const raw = request.cookies?.[SESSION_KEY]
    if (raw) {
      const unsigned = request.unsignCookie(raw)
      if (unsigned.valid && unsigned.value) await app.redis.del(`admin_session:${unsigned.value}`)
    }
    reply.clearCookie(SESSION_KEY, { path: '/admin' })
    return reply.redirect('/admin/login')
  })

  // ── Dashboard ──────────────────────────────────────────────────────────────
  app.get('/', guard, async (_request, reply) => {
    const day1 = new Date(Date.now() - 86_400_000)
    const [totalUsers, activeToday, flaggedUsers, totalRounds, openFeedback, modes] = await Promise.all([
      app.prisma.user.count(),
      app.prisma.user.count({ where: { lastActiveAt: { gte: day1 } } }),
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

  // ── Settings / change password ─────────────────────────────────────────────
  const settingsView = (reply: any, data: object = {}) =>
    reply.view('admin/settings.ejs', { title: 'Settings', ...data })

  app.get('/settings', guard, async (_request, reply) => settingsView(reply))

  app.post('/settings/change-password', guard, async (request: any, reply) => {
    const body = z.object({
      currentPassword: z.string().min(1),
      newPassword:     z.string().min(8),
      confirmPassword: z.string().min(1),
    }).safeParse(request.body)

    if (!body.success) return settingsView(reply, { error: 'Alle felt er påkrevd og nytt passord må være minst 8 tegn.' })
    if (body.data.newPassword !== body.data.confirmPassword) return settingsView(reply, { error: 'Nytt passord og bekreftelse er ikke like.' })

    const admin = await app.prisma.adminUser.findUnique({ where: { id: request.adminId } })
    if (!admin) return reply.redirect('/admin/login')

    const valid = await bcrypt.compare(body.data.currentPassword, admin.passwordHash)
    if (!valid) return settingsView(reply, { error: 'Nåværende passord er feil.' })

    const newHash = await bcrypt.hash(body.data.newPassword, 12)
    await app.prisma.adminUser.update({ where: { id: admin.id }, data: { passwordHash: newHash } })

    return settingsView(reply, { success: 'Passordet er oppdatert.' })
  })

  // ── Sub-sections ───────────────────────────────────────────────────────────
  app.register(async (sub) => {
    sub.addHook('onRequest', requireAdmin(app))
    sub.register(adminUsersRoutes,     { prefix: '/users' })
    sub.register(adminQuestionsRoutes, { prefix: '/questions' })
    sub.register(adminModesRoutes,     { prefix: '/modes' })
    sub.register(adminFeedbackRoutes,  { prefix: '/feedback' })
    sub.register(adminStatsRoutes,     { prefix: '/stats' })
  })
}

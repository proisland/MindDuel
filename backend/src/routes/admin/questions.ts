import type { FastifyInstance } from 'fastify'
import { z } from 'zod'

const questionSchema = z.object({
  id:      z.string(),
  prompt:  z.string(),
  options: z.array(z.string()).length(4),
  answer:  z.string(),
  level:   z.number().int().min(1).max(20),
})

const createPackBody = z.object({
  mode:      z.string().min(1),
  questions: z.array(questionSchema).min(1),
})

function parseCsv(csv: string): z.infer<typeof questionSchema>[] {
  const lines = csv.trim().split('\n').filter(Boolean)
  if (lines.length < 2) throw new Error('CSV must have header + at least one row')

  const headers = lines[0].split(',').map(h => h.trim().toLowerCase().replace(/^"(.*)"$/, '$1'))
  const reqCols = ['level', 'prompt', 'correct', 'distractor1', 'distractor2', 'distractor3']
  for (const col of reqCols) {
    if (!headers.includes(col)) throw new Error(`Missing column: ${col}`)
  }

  return lines.slice(1).map((line, i) => {
    // Simple CSV parse: handle quoted fields
    const cols: string[] = []
    let cur = '', inQuote = false
    for (let ci = 0; ci < line.length; ci++) {
      const ch = line[ci]
      if (ch === '"') { inQuote = !inQuote }
      else if (ch === ',' && !inQuote) { cols.push(cur); cur = '' }
      else { cur += ch }
    }
    cols.push(cur)

    const get = (col: string) => (cols[headers.indexOf(col)] ?? '').trim()
    const level = parseInt(get('level'), 10)
    if (isNaN(level) || level < 1 || level > 20) throw new Error(`Row ${i + 2}: invalid level`)

    const correct = get('correct')
    const options = [correct, get('distractor1'), get('distractor2'), get('distractor3')]
    const id = get('id') || `${Date.now()}-${i}`

    return { id, prompt: get('prompt'), options, answer: correct, level }
  })
}

export default async function adminQuestionsRoutes(app: FastifyInstance) {
  // GET /admin/questions
  app.get('/', async (_request, reply) => {
    const packs = await app.prisma.questionPack.findMany({
      orderBy: [{ mode: 'asc' }, { version: 'desc' }],
      select: { id: true, mode: true, version: true, isActive: true, createdAt: true },
    })

    const grouped: Record<string, typeof packs> = {}
    for (const p of packs) {
      grouped[p.mode] = grouped[p.mode] ?? []
      grouped[p.mode].push(p)
    }

    return reply.view('admin/questions.ejs', { title: 'Questions', grouped })
  })

  // POST /admin/questions — upload new pack (JSON body)
  app.post('/', async (request, reply) => {
    const body = createPackBody.safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body', details: body.error.flatten() })

    const latest = await app.prisma.questionPack.findFirst({
      where: { mode: body.data.mode },
      orderBy: { version: 'desc' },
      select: { version: true },
    })

    const version = (latest?.version ?? 0) + 1
    const pack = await app.prisma.questionPack.create({
      data: { mode: body.data.mode, version, data: body.data.questions, isActive: false },
    })

    return reply.status(201).send({ id: pack.id, mode: pack.mode, version: pack.version })
  })

  // POST /admin/questions/csv — upload new pack from CSV body { mode, csv }
  app.post('/csv', async (request, reply) => {
    const body = z.object({ mode: z.string().min(1), csv: z.string().min(1) }).safeParse(request.body)
    if (!body.success) return reply.status(400).send({ error: 'Invalid body' })

    let questions: ReturnType<typeof parseCsv>
    try {
      questions = parseCsv(body.data.csv)
    } catch (err: any) {
      return reply.status(400).send({ error: err.message })
    }

    const latest = await app.prisma.questionPack.findFirst({
      where: { mode: body.data.mode },
      orderBy: { version: 'desc' },
      select: { version: true },
    })

    const version = (latest?.version ?? 0) + 1
    const pack = await app.prisma.questionPack.create({
      data: { mode: body.data.mode, version, data: questions, isActive: false },
    })

    return reply.status(201).send({ id: pack.id, mode: pack.mode, version: pack.version, count: questions.length })
  })

  // GET /admin/questions/:id/csv — download pack as CSV
  app.get('/:id/csv', async (request, reply) => {
    const { id } = request.params as { id: string }
    const pack = await app.prisma.questionPack.findUnique({ where: { id } })
    if (!pack) return reply.status(404).send('Not found')

    const questions = pack.data as Array<{ id: string; prompt: string; options: string[]; answer: string; level: number }>
    const rows = questions.map(q => {
      const distractors = q.options.filter(o => o !== q.answer)
      const esc = (s: string) => `"${s.replace(/"/g, '""')}"`
      return [q.level, esc(q.prompt), esc(q.answer), esc(distractors[0] ?? ''), esc(distractors[1] ?? ''), esc(distractors[2] ?? '')].join(',')
    })

    const csv = `id,level,prompt,correct,distractor1,distractor2,distractor3\n` + rows.join('\n')
    reply.header('Content-Type', 'text/csv')
    reply.header('Content-Disposition', `attachment; filename="${pack.mode}-v${pack.version}.csv"`)
    return reply.send(csv)
  })

  // PATCH /admin/questions/:id/activate — activate pack (rolls back previous)
  app.patch('/:id/activate', async (request, reply) => {
    const { id } = request.params as { id: string }
    const pack = await app.prisma.questionPack.findUnique({ where: { id } })
    if (!pack) return reply.status(404).send({ error: 'Not found' })

    await app.prisma.$transaction([
      app.prisma.questionPack.updateMany({
        where: { mode: pack.mode, isActive: true },
        data: { isActive: false },
      }),
      app.prisma.questionPack.update({
        where: { id },
        data: { isActive: true },
      }),
    ])

    await app.redis.del('modes:active')
    return reply.send({ ok: true })
  })

  // DELETE /admin/questions/:id — delete inactive pack
  app.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string }
    const pack = await app.prisma.questionPack.findUnique({ where: { id } })
    if (!pack) return reply.status(404).send({ error: 'Not found' })
    if (pack.isActive) return reply.status(409).send({ error: 'Deactivate pack before deleting' })

    await app.prisma.questionPack.delete({ where: { id } })
    return reply.send({ ok: true })
  })
}

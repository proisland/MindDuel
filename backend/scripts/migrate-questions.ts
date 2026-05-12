/**
 * Migrate questions from iOS Swift question banks.
 *
 * CSV mode (recommended — no credentials needed):
 *   cd backend
 *   npx tsx scripts/migrate-questions.ts --csv
 *   → writes grammar.csv, history.csv, … to scripts/csv/
 *   → import each file via the admin UI at /admin/questions
 *
 * Direct DB mode:
 *   DATABASE_URL=postgresql://... npx tsx scripts/migrate-questions.ts
 *   → inserts directly into the database (packs start inactive)
 *   → use --force to add a new version even if a pack already exists
 */

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { PrismaClient } from '@prisma/client'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const APP_DIR   = path.resolve(__dirname, '../../MindDuel/Game')
const FORCE     = process.argv.includes('--force')
const CSV_MODE  = process.argv.includes('--csv')

interface Question {
  id:      string
  prompt:  string
  options: string[]
  answer:  string
  level:   number
}

function parseSwiftBank(filePath: string, slug: string): Question[] {
  const src = fs.readFileSync(filePath, 'utf-8')
  const questions: Question[] = []
  let currentLevel = 1
  const levelCounters: Record<number, number> = {}

  for (const line of src.split('\n')) {
    const levelMatch = line.match(/(?:Level|level)\s*(\d+)/)
    if (levelMatch && (line.includes('MARK') || line.includes('private static let level'))) {
      currentLevel = parseInt(levelMatch[1], 10)
      continue
    }

    const qMatch = line.match(
      /q\("((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/
    )
    if (qMatch) {
      const [, prompt, correct, d1, d2, d3] = qMatch
      levelCounters[currentLevel] = (levelCounters[currentLevel] ?? 0) + 1
      const idx = String(levelCounters[currentLevel]).padStart(3, '0')
      questions.push({
        id:      `${slug}-l${currentLevel}-${idx}`,
        prompt:  prompt.replace(/\\"/g, '"'),
        options: [correct, d1, d2, d3].map(s => s.replace(/\\"/g, '"')),
        answer:  correct.replace(/\\"/g, '"'),
        level:   currentLevel,
      })
    }
  }

  return questions
}

const MODES: Array<{ slug: string; file: string }> = [
  { slug: 'grammar', file: 'GrammarGame/GrammarQuestionBank.swift' },
  { slug: 'history', file: 'HistoryGame/HistoryQuestionBank.swift' },
  { slug: 'science', file: 'ScienceGame/ScienceQuestionBank.swift' },
  { slug: 'physics', file: 'PhysicsGame/PhysicsQuestionBank.swift' },
  { slug: 'sport',   file: 'SportGame/SportQuestionBank.swift' },
]

function toCsv(questions: Question[]): string {
  const esc = (s: string) => `"${s.replace(/"/g, '""')}"`
  const header = 'id,level,prompt,correct,distractor1,distractor2,distractor3'
  const rows = questions.map(q => {
    const [d1, d2, d3] = q.options.filter(o => o !== q.answer)
    return [q.id, q.level, esc(q.prompt), esc(q.answer), esc(d1 ?? ''), esc(d2 ?? ''), esc(d3 ?? '')].join(',')
  })
  return header + '\n' + rows.join('\n')
}

function levelSummary(questions: Question[]): string {
  const byLevel = questions.reduce<Record<number, number>>((acc, q) => {
    acc[q.level] = (acc[q.level] ?? 0) + 1; return acc
  }, {})
  return Object.entries(byLevel)
    .sort((a, b) => Number(a[0]) - Number(b[0]))
    .map(([l, n]) => `L${l}:${n}`)
    .join(' ')
}

async function runCsvMode() {
  const outDir = path.join(__dirname, 'csv')
  fs.mkdirSync(outDir, { recursive: true })
  let total = 0

  for (const { slug, file } of MODES) {
    const filePath = path.join(APP_DIR, file)
    if (!fs.existsSync(filePath)) { console.warn(`⚠  Not found: ${filePath}`); continue }

    const questions = parseSwiftBank(filePath, slug)
    const outPath   = path.join(outDir, `${slug}.csv`)
    fs.writeFileSync(outPath, toCsv(questions), 'utf-8')

    console.log(`✓  ${slug}: ${questions.length} spørsmål  [${levelSummary(questions)}]`)
    console.log(`   → ${outPath}`)
    total += questions.length
  }

  console.log(`\n${total} spørsmål eksportert til scripts/csv/`)
  console.log('\nNeste steg:')
  console.log('  1. Gå til admin-UI → Questions')
  console.log('  2. Velg modus, lim inn CSV-innhold, klikk "Last opp"')
  console.log('  3. Aktiver pakken etter verifisering')
}

async function runDbMode() {
  if (!process.env.DATABASE_URL) {
    console.error('ERROR: DATABASE_URL er påkrevd\n')
    console.error('  DATABASE_URL=postgresql://... npx tsx scripts/migrate-questions.ts')
    console.error('  eller bruk --csv for å eksportere til filer i stedet')
    process.exit(1)
  }

  const prisma = new PrismaClient()
  await prisma.$connect()
  let total = 0

  for (const { slug, file } of MODES) {
    const filePath = path.join(APP_DIR, file)
    if (!fs.existsSync(filePath)) { console.warn(`⚠  Not found: ${filePath}`); continue }

    const existing = await prisma.questionPack.findFirst({
      where: { mode: slug },
      orderBy: { version: 'desc' },
      select: { version: true },
    })

    if (existing && !FORCE) {
      console.log(`⏭  ${slug}: har allerede v${existing.version} — hopper over (bruk --force for ny versjon)`)
      continue
    }

    const questions = parseSwiftBank(filePath, slug)
    const version   = (existing?.version ?? 0) + 1
    await prisma.questionPack.create({
      data: { mode: slug, version, data: questions as any, isActive: false },
    })

    console.log(`✓  ${slug} v${version}: ${questions.length} spørsmål  [${levelSummary(questions)}]`)
    console.log(`   → Aktiver i admin-UI: /admin/questions`)
    total += questions.length
  }

  await prisma.$disconnect()
  console.log(`\nFerdig. ${total} spørsmål lagt inn (inaktive — aktiver i admin-UI).`)
}

async function main() {
  if (CSV_MODE) await runCsvMode()
  else await runDbMode()
}

main().catch(err => { console.error(err); process.exit(1) })

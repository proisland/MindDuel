/**
 * Migrate questions from iOS Swift question banks into the backend database.
 *
 * Usage:
 *   cd backend
 *   DATABASE_URL=postgresql://... npx tsx scripts/migrate-questions.ts
 *
 * Reads the 5 Swift QuestionBank files, converts to APIQuestion format,
 * and inserts each mode as a new (inactive) QuestionPack in the database.
 * Activate each pack via the admin UI after verifying.
 *
 * Safe to run multiple times — skips modes that already have packs.
 * Use --force to create a new version even if a pack already exists.
 */

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { PrismaClient } from '@prisma/client'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const APP_DIR   = path.resolve(__dirname, '../../MindDuel/Game')
const FORCE     = process.argv.includes('--force')

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

async function main() {
  if (!process.env.DATABASE_URL) {
    console.error('ERROR: DATABASE_URL is required\n')
    console.error('  DATABASE_URL=postgresql://... npx tsx scripts/migrate-questions.ts')
    process.exit(1)
  }

  const prisma = new PrismaClient()
  await prisma.$connect()

  let total = 0

  for (const { slug, file } of MODES) {
    const filePath = path.join(APP_DIR, file)
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠  Not found: ${filePath}`)
      continue
    }

    const existing = await prisma.questionPack.findFirst({
      where: { mode: slug },
      orderBy: { version: 'desc' },
      select: { version: true, isActive: true },
    })

    if (existing && !FORCE) {
      console.log(`⏭  ${slug}: already has v${existing.version} — skipping (use --force to add new version)`)
      continue
    }

    const questions = parseSwiftBank(filePath, slug)
    const byLevel   = questions.reduce<Record<number, number>>((acc, q) => {
      acc[q.level] = (acc[q.level] ?? 0) + 1; return acc
    }, {})

    const version = (existing?.version ?? 0) + 1
    await prisma.questionPack.create({
      data: { mode: slug, version, data: questions as any, isActive: false },
    })

    const levelSummary = Object.entries(byLevel)
      .sort((a, b) => Number(a[0]) - Number(b[0]))
      .map(([l, n]) => `L${l}:${n}`)
      .join(' ')

    console.log(`✓  ${slug} v${version}: ${questions.length} questions  [${levelSummary}]`)
    console.log(`   → Activate in admin UI: /admin/questions`)
    total += questions.length
  }

  await prisma.$disconnect()
  console.log(`\nFerdig. ${total} spørsmål lastet inn (pakker er inaktive — aktiver i admin-UI).`)
}

main().catch(err => { console.error(err); process.exit(1) })

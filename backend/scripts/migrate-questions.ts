/**
 * Migrate questions from iOS Swift question banks to backend.
 *
 * Usage:
 *   cd backend
 *   npx tsx scripts/migrate-questions.ts
 *
 * Reads the 5 Swift QuestionBank files, converts them to APIQuestion format,
 * and POSTs each mode as a new question pack (inactive) via the admin API.
 * Activate each pack manually via the admin UI after verifying.
 *
 * Requires ADMIN_URL and ADMIN_COOKIE env vars:
 *   ADMIN_URL=https://your-backend.up.railway.app
 *   ADMIN_COOKIE=<session cookie from /admin/login>
 */

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const APP_DIR = path.resolve(__dirname, '../../MindDuel/Game')

interface Question {
  id: string
  prompt: string
  options: string[]
  answer: string
  level: number
}

function parseSwiftBank(filePath: string, slug: string): Question[] {
  const src = fs.readFileSync(filePath, 'utf-8')
  const questions: Question[] = []

  // Detect current level from MARK comments or `private static let levelN`
  let currentLevel = 1
  const lines = src.split('\n')
  let levelCounters: Record<number, number> = {}

  for (const line of lines) {
    // Detect level markers
    const levelMatch = line.match(/(?:Level|level)\s*(\d+)/)
    if (levelMatch && (line.includes('MARK') || line.includes('private static let level'))) {
      currentLevel = parseInt(levelMatch[1], 10)
      continue
    }

    // Match q("prompt", "correct", "d1", "d2", "d3")
    const qMatch = line.match(/q\("((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/)
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

async function uploadPack(baseUrl: string, cookie: string, mode: string, questions: Question[]) {
  const res = await fetch(`${baseUrl}/admin/questions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Cookie': cookie,
    },
    body: JSON.stringify({ mode, questions }),
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Upload failed (${res.status}): ${text}`)
  }
  return res.json()
}

async function main() {
  const ADMIN_URL    = process.env.ADMIN_URL
  const ADMIN_COOKIE = process.env.ADMIN_COOKIE

  const dryRun = !ADMIN_URL || !ADMIN_COOKIE

  if (dryRun) {
    console.log('Dry-run mode (set ADMIN_URL + ADMIN_COOKIE to upload)\n')
  }

  for (const { slug, file } of MODES) {
    const filePath = path.join(APP_DIR, file)
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠ Not found: ${filePath}`)
      continue
    }

    const questions = parseSwiftBank(filePath, slug)
    const byLevel = questions.reduce<Record<number, number>>((acc, q) => {
      acc[q.level] = (acc[q.level] ?? 0) + 1
      return acc
    }, {})

    console.log(`\n${slug}: ${questions.length} questions across ${Object.keys(byLevel).length} levels`)
    for (const [lvl, count] of Object.entries(byLevel).sort((a, b) => Number(a[0]) - Number(b[0]))) {
      process.stdout.write(`  Level ${lvl}: ${count}  `)
    }
    console.log()

    if (!dryRun) {
      try {
        const result = await uploadPack(ADMIN_URL!, ADMIN_COOKIE!, slug, questions)
        console.log(`  ✓ Uploaded ${slug} v${result.version} (id: ${result.id}) — activate in admin UI`)
      } catch (err: any) {
        console.error(`  ✗ ${slug}: ${err.message}`)
      }
    } else {
      // Write JSON to disk for inspection
      const outPath = path.join(__dirname, `${slug}-questions.json`)
      fs.writeFileSync(outPath, JSON.stringify(questions, null, 2))
      console.log(`  Written to ${outPath}`)
    }
  }
}

main().catch(console.error)

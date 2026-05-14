/**
 * Translate question packs between Norwegian and English using the Claude API.
 *
 * Usage (EN → NO, legacy — reads from ~/Downloads/Spørsmålsfiler/):
 *   ANTHROPIC_API_KEY=sk-ant-... npx tsx scripts/translate-questions.ts
 *
 * Usage (NO → EN, supply input CSV files explicitly):
 *   ANTHROPIC_API_KEY=sk-ant-... npx tsx scripts/translate-questions.ts --to en scripts/csv/chem.csv scripts/csv/physics.csv
 *
 * Output:
 *   --to no  →  scripts/csv/no/<filename>
 *   --to en  →  scripts/csv/en/<filename>
 */

import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// ── CLI args ──────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2)
const toIdx = argv.indexOf('--to')
const TARGET_LANG: 'no' | 'en' = toIdx !== -1 && argv[toIdx + 1] === 'en' ? 'en' : 'no'
const inputArgs = argv.filter((a, i) => !a.startsWith('--') && argv[i - 1] !== '--to')

const API_KEY    = process.env.ANTHROPIC_API_KEY ?? ''
const MODEL      = 'claude-haiku-4-5-20251001'
const INPUT_DIR  = path.join(os.homedir(), 'Downloads/Spørsmålsfiler')
const OUTPUT_DIR = path.join(__dirname, `csv/${TARGET_LANG}`)
const BATCH_SIZE   = 20
const CONCURRENCY  = 1
const MAX_RETRIES  = 5
// ~600 output-tokens per batch; 10 000 tok/min limit → ~16 batches/min max.
// 5-second pause gives ~12 batches/min (~7 200 tok/min) with safe headroom.
const BATCH_DELAY_MS = 5_000

if (!API_KEY) {
  console.error('Mangler ANTHROPIC_API_KEY – sett environment-variabelen og prøv igjen.')
  process.exit(1)
}

interface Question {
  id: string
  level: string
  prompt: string
  correct: string
  distractor1: string
  distractor2: string
  distractor3: string
}

interface TranslationItem {
  prompt: string
  correct: string
  d1: string
  d2: string
  d3: string
}

// ── CSV helpers ───────────────────────────────────────────────────────────────

function parseCsv(content: string): Question[] {
  const lines = content.trim().split('\n').slice(1) // skip header
  return lines.map(line => {
    const cols: string[] = []
    let cur = '', inQuote = false
    for (let i = 0; i < line.length; i++) {
      const ch = line[i]
      if (ch === '"') {
        if (inQuote && line[i + 1] === '"') { cur += '"'; i++ }
        else { inQuote = !inQuote }
      } else if (ch === ',' && !inQuote) {
        cols.push(cur); cur = ''
      } else {
        cur += ch
      }
    }
    cols.push(cur)
    return {
      id:          cols[0] ?? '',
      level:       cols[1] ?? '',
      prompt:      cols[2] ?? '',
      correct:     cols[3] ?? '',
      distractor1: cols[4] ?? '',
      distractor2: cols[5] ?? '',
      distractor3: cols[6] ?? '',
    }
  })
}

function toCsvLine(q: Question): string {
  const esc = (s: string) => `"${s.replace(/"/g, '""')}"`
  return [esc(q.id), q.level, esc(q.prompt), esc(q.correct), esc(q.distractor1), esc(q.distractor2), esc(q.distractor3)].join(',')
}

// ── Claude API ────────────────────────────────────────────────────────────────

const SYSTEM_PROMPTS = {
  no: `Du er en norsk trivia-oversetter. Oversett engelske triviaspørsmål til norsk.

Regler:
- Oversett alt tekst naturlig til norsk bokmål
- Behold egennavn (personers navn, titler på filmer/bøker/sanger) i den formen som er mest kjent i Norge — ofte engelsk (f.eks. "Top Gun", "The Beatles"), men norsk der det er etablert (f.eks. "Ringenes herre")
- Informatikk: bruk norske termer der de finnes (f.eks. "datamaskin", "nettleser", "minne"), men behold universelt brukte engelske termer (f.eks. "RAM", "CPU", "cache", "kernel", "byte")
- Returner KUN et gyldig JSON-array. Ingen markdown, ingen forklaring.`,

  en: `You are a trivia translator. Translate Norwegian trivia questions into natural English.

Rules:
- Translate all text into natural, clear English
- Keep proper nouns (people's names, movie/book/song titles) in their most internationally recognised form
- Science/tech: use standard English terms (e.g. "gravity", "electron", "nucleus")
- Return ONLY a valid JSON array. No markdown, no explanation.`,
}

async function callClaude(items: TranslationItem[], mode: string, attempt: number): Promise<TranslationItem[]> {
  const userMsg = TARGET_LANG === 'en'
    ? `Translate these ${mode} trivia questions into English. Return a JSON array with the same structure.\n\n${JSON.stringify(items)}`
    : `Oversett disse ${mode}-triviaspørsmålene til norsk. Returner et JSON-array med samme struktur.\n\n${JSON.stringify(items)}`

  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 4096,
      system: SYSTEM_PROMPTS[TARGET_LANG],
      messages: [{ role: 'user', content: userMsg }],
    }),
  })

  if (!resp.ok) {
    const body = await resp.text()
    // On rate limit, surface the wait time so the retry loop can honour it
    if (resp.status === 429) {
      const retryAfter = resp.headers.get('retry-after')
      const waitSec = retryAfter ? parseInt(retryAfter, 10) : 60
      throw Object.assign(new Error(`Rate limited (attempt ${attempt})`), { retryAfterMs: waitSec * 1000 })
    }
    throw new Error(`API ${resp.status}: ${body.slice(0, 200)}`)
  }

  const data = await resp.json() as { content: Array<{ type: string; text: string }> }
  const text = data.content.find(c => c.type === 'text')?.text ?? ''

  // Strip markdown code fences if model wraps response
  const stripped = text.replace(/^```(?:json)?\n?/m, '').replace(/\n?```$/m, '').trim()

  const parsed: TranslationItem[] = JSON.parse(stripped)
  if (!Array.isArray(parsed) || parsed.length !== items.length) {
    throw new Error(`Lengdefeil: forventet ${items.length}, fikk ${Array.isArray(parsed) ? parsed.length : 'ikke-array'} (forsøk ${attempt})`)
  }
  return parsed
}

async function translateBatch(questions: Question[], mode: string): Promise<Question[]> {
  const items: TranslationItem[] = questions.map(q => ({
    prompt:  q.prompt,
    correct: q.correct,
    d1:      q.distractor1,
    d2:      q.distractor2,
    d3:      q.distractor3,
  }))

  let lastError: Error | null = null
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const translated = await callClaude(items, mode, attempt)
      return questions.map((q, i) => ({
        ...q,
        prompt:      translated[i]?.prompt      ?? q.prompt,
        correct:     translated[i]?.correct     ?? q.correct,
        distractor1: translated[i]?.d1          ?? q.distractor1,
        distractor2: translated[i]?.d2          ?? q.distractor2,
        distractor3: translated[i]?.d3          ?? q.distractor3,
      }))
    } catch (err) {
      lastError = err as Error
      if (attempt < MAX_RETRIES) {
        const rateLimitWait = (err as any).retryAfterMs as number | undefined
        const waitMs = rateLimitWait ?? 2000 * attempt
        if (rateLimitWait) process.stdout.write(`\n  ⏳ rate limit – venter ${waitMs / 1000}s...\n`)
        await new Promise(r => setTimeout(r, waitMs))
      }
    }
  }
  throw lastError
}

// ── File processing ───────────────────────────────────────────────────────────

async function processFile(csvFile: string): Promise<void> {
  const filename = path.basename(csvFile)
  // Mode label: strip known suffixes like -en-v1, -no-v1, or just use stem
  const mode = filename.replace(/(-(?:en|no)-v\d+)?\.csv$/, '')
  const outPath = path.join(OUTPUT_DIR, filename)

  process.stdout.write(`\n── ${mode} ──\n`)
  const questions = parseCsv(fs.readFileSync(csvFile, 'utf-8'))
  process.stdout.write(`  ${questions.length} questions to translate\n`)

  // Split into batches
  const batches: Question[][] = []
  for (let i = 0; i < questions.length; i += BATCH_SIZE) {
    batches.push(questions.slice(i, i + BATCH_SIZE))
  }

  const translated: Question[] = new Array(questions.length)
  let done = 0

  // Process batches sequentially with a pacing delay to stay under rate limit
  for (let i = 0; i < batches.length; i += CONCURRENCY) {
    const chunk = batches.slice(i, i + CONCURRENCY)
    const results = await Promise.all(
      chunk.map((batch, ci) =>
        translateBatch(batch, mode).then(r => ({ r, offset: (i + ci) * BATCH_SIZE }))
      )
    )
    for (const { r, offset } of results) {
      for (let j = 0; j < r.length; j++) translated[offset + j] = r[j]
      done += r.length
    }
    process.stdout.write(`\r  ${done}/${questions.length} translated...`)
    if (i + CONCURRENCY < batches.length) {
      await new Promise(r => setTimeout(r, BATCH_DELAY_MS))
    }
  }

  process.stdout.write(`\r  ✓ ${done} questions translated to ${TARGET_LANG}\n`)

  const csv = `id,level,prompt,correct,distractor1,distractor2,distractor3\n` + translated.map(toCsvLine).join('\n')
  fs.writeFileSync(outPath, csv, 'utf-8')
  process.stdout.write(`  → scripts/csv/${TARGET_LANG}/${filename}\n`)
}

// ── Entry point ───────────────────────────────────────────────────────────────

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true })

  // Use explicit file args if given; fall back to INPUT_DIR for legacy EN→NO flow
  const files: string[] = inputArgs.length > 0
    ? inputArgs.map(f => path.resolve(f))
    : fs.readdirSync(INPUT_DIR)
        .filter(f => f.endsWith('.csv'))
        .sort()
        .map(f => path.join(INPUT_DIR, f))

  if (files.length === 0) {
    console.error(inputArgs.length > 0
      ? `No input files found.`
      : `Ingen CSV-filer funnet i ${INPUT_DIR}`)
    process.exit(1)
  }

  console.log(`Translating ${files.length} file(s) → ${TARGET_LANG.toUpperCase()} with ${MODEL}...`)
  const start = Date.now()

  for (const file of files) {
    await processFile(file)
  }

  const elapsed = ((Date.now() - start) / 1000).toFixed(1)
  console.log(`\n✓ Done in ${elapsed}s.`)
  console.log(`  Upload CSV files from scripts/csv/${TARGET_LANG}/ via the admin UI (language: ${TARGET_LANG}).`)
}

main().catch(err => { console.error(err); process.exit(1) })

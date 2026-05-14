/**
 * Sync missing game modes and question packs from a source database to a target database.
 *
 * Usage:
 *   SOURCE_DATABASE_URL="postgresql://..." TARGET_DATABASE_URL="postgresql://..." npx tsx scripts/sync-to-staging.ts
 *
 * Defaults:
 *   SOURCE defaults to local docker (postgresql://mindduel:mindduel@localhost:5432/mindduel)
 *   TARGET must be set explicitly
 */

import { PrismaClient } from '@prisma/client'

const SOURCE_URL = process.env.SOURCE_DATABASE_URL ?? 'postgresql://mindduel:mindduel@localhost:5432/mindduel'
const TARGET_URL = process.env.TARGET_DATABASE_URL

if (!TARGET_URL) {
  console.error('Error: TARGET_DATABASE_URL is required')
  process.exit(1)
}

const source = new PrismaClient({ datasources: { db: { url: SOURCE_URL } } })
const target = new PrismaClient({ datasources: { db: { url: TARGET_URL } } })

async function main() {
  // ── Game modes ──────────────────────────────────────────────────────────────
  const [sourceModes, targetModes] = await Promise.all([
    source.gameMode.findMany({ orderBy: { sortOrder: 'asc' } }),
    target.gameMode.findMany(),
  ])
  const targetSlugs = new Set(targetModes.map(m => m.slug))

  let modesAdded = 0
  for (const mode of sourceModes) {
    if (targetSlugs.has(mode.slug)) continue
    await target.gameMode.create({
      data: {
        id:          mode.id,
        slug:        mode.slug,
        name:        mode.name,
        nameNo:      mode.nameNo,
        nameEn:      mode.nameEn,
        isActive:    mode.isActive,
        iconSymbol:  mode.iconSymbol,
        colorHex:    mode.colorHex,
        sortOrder:   mode.sortOrder,
        startsAt:    mode.startsAt,
        endsAt:      mode.endsAt,
        createdAt:   mode.createdAt,
        updatedAt:   mode.updatedAt,
      },
    })
    console.log(`+ mode: ${mode.slug} (${mode.nameNo})`)
    modesAdded++
  }
  if (modesAdded === 0) console.log('  modes: nothing to add')

  // ── Question packs ──────────────────────────────────────────────────────────
  const [sourcePacks, targetPacks] = await Promise.all([
    source.questionPack.findMany({ where: { isActive: true } }),
    target.questionPack.findMany(),
  ])

  // Key: mode+language+version
  const targetPackKeys = new Set(
    targetPacks.map(p => `${p.mode}|${(p as any).language ?? 'no'}|${p.version}`)
  )

  let packsAdded = 0
  for (const pack of sourcePacks) {
    const lang = (pack as any).language ?? 'no'
    const key = `${pack.mode}|${lang}|${pack.version}`
    if (targetPackKeys.has(key)) continue
    await target.$executeRawUnsafe(
      `INSERT INTO "QuestionPack" (id, mode, language, version, data, "isActive", "createdAt")
       VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)`,
      pack.id, pack.mode, lang, pack.version, JSON.stringify(pack.data), pack.isActive, pack.createdAt
    )
    console.log(`+ pack: ${pack.mode} [${lang}] v${pack.version}`)
    packsAdded++
  }
  if (packsAdded === 0) console.log('  packs: nothing to add')

  console.log(`\nDone — ${modesAdded} mode(s), ${packsAdded} pack(s) added.`)
}

main()
  .catch(e => { console.error(e); process.exit(1) })
  .finally(async () => { await source.$disconnect(); await target.$disconnect() })

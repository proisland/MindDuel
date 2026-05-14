/**
 * Run EXPLAIN ANALYZE on the key application queries and print the results.
 *
 * Usage (against staging):
 *   DATABASE_URL="postgresql://..." npx tsx scripts/explain-analyze.ts
 */

import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

interface ExplainRow { 'QUERY PLAN': string }

async function explain(label: string, sql: string, params: unknown[] = []) {
  process.stdout.write(`\n── ${label} ──\n`)
  const rows = await prisma.$queryRawUnsafe<ExplainRow[]>(
    `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) ${sql}`,
    ...params,
  )
  for (const row of rows) process.stdout.write(row['QUERY PLAN'] + '\n')
}

async function main() {
  // Leaderboard: global top-50 by score
  await explain(
    'Leaderboard – global top-50',
    `SELECT u.username, u."avatarEmoji", SUM(gs.score) AS total
     FROM "GameSession" gs
     JOIN "User" u ON u.id = gs."userId"
     WHERE gs."endedAt" IS NOT NULL
     GROUP BY u.id, u.username, u."avatarEmoji"
     ORDER BY total DESC
     LIMIT 50`,
  )

  // Active game modes + active question packs
  await explain(
    'Active game modes with active packs',
    `SELECT gm.slug, qp.language, qp.version
     FROM "GameMode" gm
     LEFT JOIN "QuestionPack" qp
       ON qp.mode = gm.slug AND qp."isActive" = true AND qp.language = $1
     WHERE gm."isActive" = true
     ORDER BY gm."sortOrder"`,
    ['no'],
  )

  // User lookup by Apple ID (auth hot path)
  await explain(
    'User lookup by appleUserId',
    `SELECT id, username, "isSuspended" FROM "User" WHERE "appleUserId" = $1`,
    ['placeholder-apple-id'],
  )

  // Username search with trigram index
  await explain(
    'Username ILIKE search (trigram)',
    `SELECT id, username, "avatarEmoji" FROM "User"
     WHERE username ILIKE $1
     LIMIT 20`,
    ['%test%'],
  )

  // Pending feedback (admin dashboard)
  await explain(
    'Pending feedback list',
    `SELECT id, message, "createdAt"
     FROM "Feedback"
     WHERE status = 'open'
     ORDER BY "createdAt" DESC
     LIMIT 50`,
  )

  // Recent sessions for a user (progression sync)
  await explain(
    'Recent GameSessions for a user',
    `SELECT id, mode, score, "startedAt", "endedAt"
     FROM "GameSession"
     WHERE "userId" = $1
     ORDER BY "startedAt" DESC
     LIMIT 20`,
    ['placeholder-user-id'],
  )
}

main()
  .catch(err => { console.error(err); process.exit(1) })
  .finally(() => prisma.$disconnect())

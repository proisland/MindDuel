import type { PrismaClient } from '@prisma/client'

/**
 * Idempotent schema migrations run at startup.
 * Each statement uses IF NOT EXISTS / IF column NOT EXISTS so they're safe
 * to run on every boot without a migration history file.
 */
export async function runStartupMigrations(prisma: PrismaClient) {
  await prisma.$executeRawUnsafe(`
    ALTER TABLE "User"
      ADD COLUMN IF NOT EXISTS "locale" TEXT
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "Feedback"
      ADD COLUMN IF NOT EXISTS "imageUrl" TEXT
  `)

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "FeedbackComment" (
      "id"         TEXT        NOT NULL,
      "feedbackId" TEXT        NOT NULL,
      "body"       TEXT        NOT NULL,
      "notified"   BOOLEAN     NOT NULL DEFAULT false,
      "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "FeedbackComment_pkey" PRIMARY KEY ("id"),
      CONSTRAINT "FeedbackComment_feedbackId_fkey"
        FOREIGN KEY ("feedbackId") REFERENCES "Feedback"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
    )
  `)

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "FeedbackComment_feedbackId_createdAt_idx"
      ON "FeedbackComment"("feedbackId", "createdAt" DESC)
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "GameSession"
      ADD COLUMN IF NOT EXISTS "startPosition" INTEGER NOT NULL DEFAULT 0
  `)

  // Seed the 10 built-in game modes as active if they don't already exist.
  // Uses ON CONFLICT DO NOTHING so re-runs are safe and admin edits are preserved.
  const defaultModes = [
    { slug: 'pi',      name: 'Pi',            sortOrder: 1 },
    { slug: 'math',    name: 'Matte',         sortOrder: 2 },
    { slug: 'chem',    name: 'Kjemi',         sortOrder: 3 },
    { slug: 'geo',     name: 'Geografi',      sortOrder: 4 },
    { slug: 'brain',   name: 'Hjerne',        sortOrder: 5 },
    { slug: 'science', name: 'Vitenskap',     sortOrder: 6 },
    { slug: 'history', name: 'Historie',      sortOrder: 7 },
    { slug: 'physics', name: 'Fysikk',        sortOrder: 8 },
    { slug: 'sport',   name: 'Sport',         sortOrder: 9 },
    { slug: 'grammar', name: 'Grammatikk',    sortOrder: 10 },
  ]
  for (const m of defaultModes) {
    await prisma.$executeRawUnsafe(
      `INSERT INTO "GameMode" (id, slug, name, "isActive", "sortOrder", "createdAt", "updatedAt")
       VALUES (gen_random_uuid()::text, $1, $2, true, $3, NOW(), NOW())
       ON CONFLICT (slug) DO NOTHING`,
      m.slug, m.name, m.sortOrder,
    )
  }

}

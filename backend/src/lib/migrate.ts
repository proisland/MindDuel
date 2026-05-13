import type { PrismaClient } from '@prisma/client'

// Distinctive bigint constant used as a PostgreSQL advisory lock key to
// serialize startup migrations across rolling-deploy instances.
const MIGRATION_LOCK_KEY = BigInt('8675309001')

export async function runStartupMigrations(prisma: PrismaClient) {
  await prisma.$executeRaw`SELECT pg_advisory_lock(${MIGRATION_LOCK_KEY})`
  try {
    await runMigrationsInternal(prisma)
  } finally {
    await prisma.$executeRaw`SELECT pg_advisory_unlock(${MIGRATION_LOCK_KEY})`
  }
}

async function runMigrationsInternal(prisma: PrismaClient) {
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

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "QuestionPack"
      ADD COLUMN IF NOT EXISTS "language" TEXT NOT NULL DEFAULT 'no'
  `)

  // Replace the old (mode, version) unique constraint/index with (mode, language, version).
  // Prisma creates unique constraints as indexes, so we must DROP INDEX (not DROP CONSTRAINT).
  await prisma.$executeRawUnsafe(`
    DROP INDEX IF EXISTS "QuestionPack_mode_version_key"
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "QuestionPack"
      DROP CONSTRAINT IF EXISTS "QuestionPack_mode_version_key"
  `)

  await prisma.$executeRawUnsafe(`
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'QuestionPack_mode_language_version_key'
      ) THEN
        ALTER TABLE "QuestionPack"
          ADD CONSTRAINT "QuestionPack_mode_language_version_key"
          UNIQUE ("mode", "language", "version");
      END IF;
    END $$
  `)

  await prisma.$executeRawUnsafe(`
    DROP INDEX IF EXISTS "QuestionPack_mode_isActive_idx"
  `)

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "QuestionPack_mode_language_isActive_idx"
      ON "QuestionPack"("mode", "language", "isActive")
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "GameMode"
      ADD COLUMN IF NOT EXISTS "iconSymbol" TEXT NOT NULL DEFAULT 'questionmark'
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "GameMode"
      ADD COLUMN IF NOT EXISTS "colorHex" TEXT NOT NULL DEFAULT '#6366F1'
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "GameMode"
      ADD COLUMN IF NOT EXISTS "nameNo" TEXT NOT NULL DEFAULT ''
  `)

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "GameMode"
      ADD COLUMN IF NOT EXISTS "nameEn" TEXT NOT NULL DEFAULT ''
  `)

  // Seed the built-in game modes with icon, color, and bilingual names.
  // ON CONFLICT DO NOTHING preserves rows added before this migration.
  const defaultModes = [
    { slug: 'pi',           nameNo: 'Pi',            nameEn: 'Pi Mode',         sortOrder: 1,  iconSymbol: 'text.cursor',              colorHex: '#6366F1' },
    { slug: 'math',         nameNo: 'Matte',         nameEn: 'Math',            sortOrder: 2,  iconSymbol: 'function',                 colorHex: '#EC4899' },
    { slug: 'chem',         nameNo: 'Kjemi',         nameEn: 'Chemistry',       sortOrder: 3,  iconSymbol: 'flask.fill',               colorHex: '#22C55E' },
    { slug: 'geo',          nameNo: 'Geografi',      nameEn: 'Geography',       sortOrder: 4,  iconSymbol: 'globe.europe.africa.fill', colorHex: '#F59E0B' },
    { slug: 'brain',        nameNo: 'Hjernetrim',    nameEn: 'Brain Training',  sortOrder: 5,  iconSymbol: 'brain.head.profile',       colorHex: '#EF4444' },
    { slug: 'science',      nameNo: 'Naturvitenskap',nameEn: 'Science',         sortOrder: 6,  iconSymbol: 'atom',                     colorHex: '#6366F1' },
    { slug: 'history',      nameNo: 'Historie',      nameEn: 'History',         sortOrder: 7,  iconSymbol: 'scroll.fill',              colorHex: '#F59E0B' },
    { slug: 'physics',      nameNo: 'Fysikk',        nameEn: 'Physics',         sortOrder: 8,  iconSymbol: 'bolt.fill',                colorHex: '#EC4899' },
    { slug: 'sport',        nameNo: 'Sport',         nameEn: 'Sports',          sortOrder: 9,  iconSymbol: 'figure.run',               colorHex: '#22C55E' },
    { slug: 'grammar',      nameNo: 'Grammatikk',    nameEn: 'Grammar',         sortOrder: 10, iconSymbol: 'text.book.closed.fill',    colorHex: '#6366F1' },
    { slug: 'sci_computer', nameNo: 'Informatikk',   nameEn: 'Computer Science',sortOrder: 11, iconSymbol: 'desktopcomputer',          colorHex: '#0EA5E9' },
  ]
  for (const m of defaultModes) {
    await prisma.$executeRawUnsafe(
      `INSERT INTO "GameMode" (id, slug, name, "nameNo", "nameEn", "isActive", "iconSymbol", "colorHex", "sortOrder", "createdAt", "updatedAt")
       VALUES (gen_random_uuid()::text, $1, $2, $2, $3, true, $4, $5, $6, NOW(), NOW())
       ON CONFLICT (slug) DO NOTHING`,
      m.slug, m.nameNo, m.nameEn, m.iconSymbol, m.colorHex, m.sortOrder,
    )
    // Backfill icon/color only for rows that still carry the column default — preserves admin edits.
    await prisma.$executeRawUnsafe(
      `UPDATE "GameMode" SET "iconSymbol" = $1, "colorHex" = $2
       WHERE slug = $3 AND "iconSymbol" = 'questionmark' AND "colorHex" = '#6366F1'`,
      m.iconSymbol, m.colorHex, m.slug,
    )
    // Backfill nameNo from name where nameNo is still empty (existing rows).
    await prisma.$executeRawUnsafe(
      `UPDATE "GameMode" SET "nameNo" = name WHERE slug = $1 AND "nameNo" = ''`,
      m.slug,
    )
    // Backfill nameEn where still empty.
    await prisma.$executeRawUnsafe(
      `UPDATE "GameMode" SET "nameEn" = $1 WHERE slug = $2 AND "nameEn" = ''`,
      m.nameEn, m.slug,
    )
  }

  // For any remaining modes not in defaultModes, copy name → nameNo.
  await prisma.$executeRawUnsafe(`
    UPDATE "GameMode" SET "nameNo" = name WHERE "nameNo" = ''
  `)

  // Enable trigram extension for fast ILIKE username search.
  await prisma.$executeRawUnsafe(`CREATE EXTENSION IF NOT EXISTS pg_trgm`)

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "User_username_trgm_idx"
      ON "User" USING GIN (username gin_trgm_ops)
  `)

}

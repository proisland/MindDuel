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

}

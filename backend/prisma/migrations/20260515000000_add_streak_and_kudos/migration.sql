-- Add streak tracking fields to Progression
ALTER TABLE "Progression"
  ADD COLUMN "currentStreak"  INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "longestStreak"  INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lastPlayedDate" TEXT;

-- Create ActivityKudos table
CREATE TABLE "ActivityKudos" (
  "id"         TEXT NOT NULL,
  "fromUserId" TEXT NOT NULL,
  "toUserId"   TEXT NOT NULL,
  "roomId"     TEXT NOT NULL,
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "ActivityKudos_pkey" PRIMARY KEY ("id")
);

-- Unique: one kudos per sender per room
CREATE UNIQUE INDEX "ActivityKudos_fromUserId_roomId_key"
  ON "ActivityKudos"("fromUserId", "roomId");

-- Index for fetching kudos received by a user (newest first)
CREATE INDEX "ActivityKudos_toUserId_createdAt_idx"
  ON "ActivityKudos"("toUserId", "createdAt" DESC);

-- Foreign keys
ALTER TABLE "ActivityKudos"
  ADD CONSTRAINT "ActivityKudos_fromUserId_fkey"
    FOREIGN KEY ("fromUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "ActivityKudos_toUserId_fkey"
    FOREIGN KEY ("toUserId")   REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Add language column to QuestionPack (defaults to "no" for existing rows)
ALTER TABLE "QuestionPack" ADD COLUMN "language" TEXT NOT NULL DEFAULT 'no';

-- Drop old unique constraint and index
DROP INDEX IF EXISTS "QuestionPack_mode_version_key";
DROP INDEX IF EXISTS "QuestionPack_mode_isActive_idx";

-- Add new unique constraint and index that include language
ALTER TABLE "QuestionPack" ADD CONSTRAINT "QuestionPack_mode_language_version_key" UNIQUE ("mode", "language", "version");
CREATE INDEX "QuestionPack_mode_language_isActive_idx" ON "QuestionPack"("mode", "language", "isActive");

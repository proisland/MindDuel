-- Add locale to User (for language distribution stats)
ALTER TABLE "User" ADD COLUMN "locale" TEXT;

-- Add imageUrl to Feedback (for image attachments)
ALTER TABLE "Feedback" ADD COLUMN "imageUrl" TEXT;

-- Add FeedbackComment table (for admin comments without closing a ticket)
CREATE TABLE "FeedbackComment" (
    "id"         TEXT NOT NULL,
    "feedbackId" TEXT NOT NULL,
    "body"       TEXT NOT NULL,
    "notified"   BOOLEAN NOT NULL DEFAULT false,
    "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeedbackComment_pkey" PRIMARY KEY ("id")
);

-- Index for efficient lookup by ticket
CREATE INDEX "FeedbackComment_feedbackId_createdAt_idx" ON "FeedbackComment"("feedbackId", "createdAt" DESC);

-- Foreign key to Feedback
ALTER TABLE "FeedbackComment" ADD CONSTRAINT "FeedbackComment_feedbackId_fkey"
    FOREIGN KEY ("feedbackId") REFERENCES "Feedback"("id") ON DELETE CASCADE ON UPDATE CASCADE;

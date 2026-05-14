-- Additive: add subscription expiry and product tracking to User
ALTER TABLE "User"
  ADD COLUMN IF NOT EXISTS "premiumExpiresAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "premiumProductId" TEXT;

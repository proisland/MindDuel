#!/bin/sh
set -e

# Fix known failed migrations by marking them as applied without re-running SQL.
# These failed because migrate.ts had already applied equivalent changes via
# IF NOT EXISTS DDL, leaving Prisma's migration table out of sync.
node_modules/.bin/prisma db execute \
  --schema=prisma/schema.prisma \
  --stdin <<'SQL' 2>&1 || true
UPDATE "_prisma_migrations"
SET finished_at = NOW(),
    applied_steps_count = 1,
    logs = NULL,
    rolled_back_at = NULL
WHERE migration_name IN (
  '20260515144517_add_streak_and_kudos',
  '20260517000000_add_user_avatar_url'
)
  AND finished_at IS NULL;
SQL

node_modules/.bin/prisma migrate deploy || {
  echo "Warning: prisma migrate deploy exited with $? — continuing startup"
}

exec node dist/server.js

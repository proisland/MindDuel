#!/bin/sh
set -e

# 20260515144517_add_streak_and_kudos failed because migrate.ts had already
# added the same GameMode columns (IF NOT EXISTS). Mark it as applied directly
# in _prisma_migrations so Prisma skips re-running the SQL.
node_modules/.bin/prisma db execute \
  --schema=prisma/schema.prisma \
  --stdin <<'SQL' 2>&1 || true
UPDATE "_prisma_migrations"
SET finished_at = NOW(),
    applied_steps_count = 1,
    logs = NULL,
    rolled_back_at = NULL
WHERE migration_name = '20260515144517_add_streak_and_kudos'
  AND finished_at IS NULL;
SQL

node_modules/.bin/prisma migrate deploy || {
  echo "Warning: prisma migrate deploy exited with $? — continuing startup"
}

exec node dist/server.js

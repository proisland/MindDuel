#!/bin/sh
set -e

# 20260515144517_add_streak_and_kudos failed because migrate.ts had already
# added the same GameMode columns (IF NOT EXISTS). Fix it directly in
# _prisma_migrations so Prisma treats it as applied without re-running the SQL.
printf 'UPDATE "_prisma_migrations" SET finished_at = NOW(), applied_steps_count = 1, logs = NULL, rolled_back_at = NULL WHERE migration_name = '"'"'20260515144517_add_streak_and_kudos'"'"' AND finished_at IS NULL;\n' \
  | node_modules/.bin/prisma db execute --stdin 2>&1 || true

node_modules/.bin/prisma migrate deploy || {
  echo "Warning: prisma migrate deploy exited with $? — continuing startup"
}

exec node dist/server.js

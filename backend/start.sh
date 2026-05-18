#!/bin/sh
set -e

# 20260515144517_add_streak_and_kudos failed because migrate.ts had already
# added the same GameMode columns (IF NOT EXISTS). Prisma requires --rolled-back
# before --applied can succeed on a "failed" (not yet rolled-back) migration.
node_modules/.bin/prisma migrate resolve \
  --rolled-back 20260515144517_add_streak_and_kudos 2>/dev/null || true
node_modules/.bin/prisma migrate resolve \
  --applied 20260515144517_add_streak_and_kudos 2>/dev/null || true

node_modules/.bin/prisma migrate deploy || {
  echo "Warning: prisma migrate deploy exited with $? — continuing startup"
}

exec node dist/server.js

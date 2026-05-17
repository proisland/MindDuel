#!/bin/sh
set -e

# 20260515144517_add_streak_and_kudos failed because migrate.ts had already
# added the same GameMode columns (IF NOT EXISTS). Mark it applied so the
# subsequent add_user_avatar_url migration and all future migrations can run.
node_modules/.bin/prisma migrate resolve \
  --applied 20260515144517_add_streak_and_kudos 2>/dev/null || true

node_modules/.bin/prisma migrate deploy || {
  echo "Warning: prisma migrate deploy exited with $? — continuing startup"
}

exec node dist/server.js

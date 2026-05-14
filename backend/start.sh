#!/bin/sh
set -e

node_modules/.bin/prisma migrate deploy || {
  echo "Warning: prisma migrate deploy exited with $? — continuing startup"
}

exec node dist/server.js

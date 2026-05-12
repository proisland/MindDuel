import crypto from 'crypto'
import type { Redis } from 'ioredis'
import { config } from '../config'

const REFRESH_PREFIX = 'refresh:'

export function generateRefreshToken(): string {
  return crypto.randomBytes(40).toString('hex')
}

export async function storeRefreshToken(redis: Redis, userId: string, token: string): Promise<void> {
  await redis.set(
    `${REFRESH_PREFIX}${token}`,
    userId,
    'EX',
    config.jwt.refreshTtlSeconds,
  )
}

export async function consumeRefreshToken(redis: Redis, token: string): Promise<string | null> {
  const userId = await redis.get(`${REFRESH_PREFIX}${token}`)
  if (!userId) return null
  await redis.del(`${REFRESH_PREFIX}${token}`)
  return userId
}

export async function revokeAllRefreshTokens(redis: Redis, userId: string): Promise<void> {
  // Tokens are stored by token value → userId, not by userId → tokens.
  // For logout, the client simply discards the token. For full revocation
  // (e.g. account suspension), scan and delete matching keys.
  // This is acceptable for an MVP; a dedicated token table can replace it later.
  const keys = await redis.keys(`${REFRESH_PREFIX}*`)
  for (const key of keys) {
    const val = await redis.get(key)
    if (val === userId) await redis.del(key)
  }
}

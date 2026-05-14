import crypto from 'crypto'
import type { Redis } from 'ioredis'
import { config } from '../config'

const REFRESH_PREFIX = 'refresh:'
const USER_TOKENS_PREFIX = 'user-tokens:'

export function generateRefreshToken(): string {
  return crypto.randomBytes(40).toString('hex')
}

export async function storeRefreshToken(redis: Redis, userId: string, token: string): Promise<void> {
  const tokenKey = `${REFRESH_PREFIX}${token}`
  const userTokensKey = `${USER_TOKENS_PREFIX}${userId}`
  const ttl = config.jwt.refreshTtlSeconds
  await redis
    .multi()
    .set(tokenKey, userId, 'EX', ttl)
    .sadd(userTokensKey, tokenKey)
    .expire(userTokensKey, ttl)
    .exec()
}

export async function consumeRefreshToken(redis: Redis, token: string): Promise<string | null> {
  const tokenKey = `${REFRESH_PREFIX}${token}`
  const userId = await redis.get(tokenKey)
  if (!userId) return null
  await redis
    .multi()
    .del(tokenKey)
    .srem(`${USER_TOKENS_PREFIX}${userId}`, tokenKey)
    .exec()
  return userId
}

export async function revokeAllRefreshTokens(redis: Redis, userId: string): Promise<void> {
  const userTokensKey = `${USER_TOKENS_PREFIX}${userId}`
  const tokenKeys = await redis.smembers(userTokensKey)
  const pipeline = redis.pipeline()
  tokenKeys.forEach(k => pipeline.del(k))
  pipeline.del(userTokensKey)
  await pipeline.exec()
}

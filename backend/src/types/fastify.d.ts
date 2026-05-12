import { PrismaClient } from '@prisma/client'
import { Redis } from 'ioredis'
import { S3Client } from '@aws-sdk/client-s3'

declare module 'fastify' {
  interface FastifyInstance {
    prisma: PrismaClient
    redis: Redis
    s3: S3Client
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>
  }

  interface FastifyRequest {
    userId: string
  }
}

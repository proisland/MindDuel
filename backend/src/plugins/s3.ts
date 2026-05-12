import fp from 'fastify-plugin'
import { S3Client } from '@aws-sdk/client-s3'
import type { FastifyInstance } from 'fastify'
import { config } from '../config'

export default fp(async (app: FastifyInstance) => {
  const s3 = new S3Client({
    endpoint: config.s3.endpoint,
    region: config.s3.region,
    credentials: {
      accessKeyId: config.s3.accessKey,
      secretAccessKey: config.s3.secretKey,
    },
    forcePathStyle: true, // required for MinIO
  })

  app.decorate('s3', s3)
})

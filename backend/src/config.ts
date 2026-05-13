function required(key: string): string {
  const val = process.env[key]
  if (!val) throw new Error(`Missing required env var: ${key}`)
  return val
}

export const config = {
  port: parseInt(process.env.PORT ?? '3000', 10),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  isDev: process.env.NODE_ENV !== 'production',

  db: {
    url: required('DATABASE_URL'),
  },

  redis: {
    url: required('REDIS_URL'),
  },

  s3: {
    endpoint: required('S3_ENDPOINT'),
    bucket: required('S3_BUCKET'),
    accessKey: required('S3_ACCESS_KEY'),
    secretKey: required('S3_SECRET_KEY'),
    region: process.env.S3_REGION ?? 'us-east-1',
  },

  jwt: {
    secret: required('JWT_SECRET'),
    accessTtlSeconds: 60 * 60,        // 1 hour
    refreshTtlSeconds: 60 * 60 * 24 * 90, // 90 days
  },

  apple: {
    clientId: required('APPLE_CLIENT_ID'),
  },

  admin: {
    sessionSecret: process.env.NODE_ENV === 'production'
      ? required('ADMIN_SESSION_SECRET')
      : (process.env.ADMIN_SESSION_SECRET ?? 'dev-admin-secret'),
  },

  quota: {
    freeLimit: 20,
  },

  apns: {
    keyId:          process.env.APNS_KEY_ID ?? '',
    teamId:         process.env.APNS_TEAM_ID ?? '',
    bundleId:       process.env.APNS_BUNDLE_ID ?? '',
    privateKeyBase64: process.env.APNS_PRIVATE_KEY_BASE64 ?? '',
  },
} as const

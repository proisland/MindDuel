import { createRemoteJWKSet, jwtVerify } from 'jose'

const APPLE_ISSUER = 'https://appleid.apple.com'
const appleJWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'))

export interface AppleTokenPayload {
  appleUserId: string
  email?: string
}

export async function verifyAppleIdToken(
  idToken: string,
  clientId: string,
): Promise<AppleTokenPayload> {
  const { payload } = await jwtVerify(idToken, appleJWKS, {
    issuer: APPLE_ISSUER,
    audience: clientId,
  })

  if (typeof payload.sub !== 'string') {
    throw new Error('Invalid Apple token: missing sub')
  }

  return {
    appleUserId: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : undefined,
  }
}

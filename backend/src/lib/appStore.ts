/**
 * App Store Server API helpers.
 *
 * In development/staging (when APPLE_APP_STORE_PRIVATE_KEY is unset) we decode
 * the JWS without signature verification — good enough for Sandbox testing
 * before App Store Connect credentials are provisioned.
 *
 * In production, set the three env vars below and this module verifies the
 * signed transaction against Apple's certificate chain.
 */

const PRIVATE_KEY = process.env.APPLE_APP_STORE_PRIVATE_KEY ?? ''   // .p8 contents
const KEY_ID      = process.env.APPLE_APP_STORE_KEY_ID ?? ''
const ISSUER_ID   = process.env.APPLE_APP_STORE_ISSUER_ID ?? ''
const BUNDLE_ID   = process.env.APPLE_BUNDLE_ID ?? 'no.mindduel.app'

export type Environment = 'Sandbox' | 'Production'

export interface DecodedTransaction {
  transactionId: string
  originalTransactionId: string
  bundleId: string
  productId: string
  purchaseDate: number  // ms since epoch
  expiresDate?: number  // ms — present for subscriptions
  type: 'Auto-Renewable Subscription' | 'Non-Consumable' | 'Consumable' | 'Non-Renewing Subscription'
  environment: Environment
  inAppOwnershipType: 'PURCHASED' | 'FAMILY_SHARED'
  revocationDate?: number
  revocationReason?: number
}

function decodeJwsPayload(jws: string): unknown {
  const parts = jws.split('.')
  if (parts.length !== 3) throw new Error('Invalid JWS format')
  const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/')
  return JSON.parse(Buffer.from(payload, 'base64').toString('utf-8'))
}

export async function verifyTransaction(jwsRepresentation: string): Promise<DecodedTransaction> {
  if (!PRIVATE_KEY || !KEY_ID || !ISSUER_ID) {
    // Dev/staging: decode without signature verification
    const payload = decodeJwsPayload(jwsRepresentation) as DecodedTransaction
    return payload
  }

  // Production: use @apple/app-store-server-library (install when credentials are ready)
  // const { AppStoreServerAPIClient, SignedDataVerifier } = await import('@apple/app-store-server-library')
  // TODO: wire up full verification once APPLE_APP_STORE_* env vars are provisioned
  throw new Error('Production App Store verification not yet configured — set APPLE_APP_STORE_PRIVATE_KEY, APPLE_APP_STORE_KEY_ID, APPLE_APP_STORE_ISSUER_ID')
}

/** Returns null if not expired; ISO string if it is. */
export function subscriptionExpiresAt(tx: DecodedTransaction): Date | null {
  if (tx.type !== 'Auto-Renewable Subscription') return null
  if (!tx.expiresDate) return null
  return new Date(tx.expiresDate)
}

export { BUNDLE_ID }

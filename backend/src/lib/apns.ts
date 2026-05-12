import { type KeyLike, SignJWT, importPKCS8 } from 'jose'
import http2 from 'node:http2'
import { config } from '../config'

let cachedKey: KeyLike | null = null
let cachedToken: { token: string; issuedAt: number } | null = null

async function getJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && now - cachedToken.issuedAt < 55 * 60) return cachedToken.token

  if (!cachedKey) {
    const pem = Buffer.from(config.apns.privateKeyBase64, 'base64').toString('utf-8')
    cachedKey = await importPKCS8(pem, 'ES256')
  }

  const token = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: config.apns.keyId })
    .setIssuedAt()
    .setIssuer(config.apns.teamId)
    .sign(cachedKey!)

  cachedToken = { token, issuedAt: now }
  return token
}

export async function sendPush(deviceToken: string, title: string, body: string): Promise<void> {
  if (!config.apns.keyId || !config.apns.teamId || !config.apns.privateKeyBase64 || !config.apns.bundleId) return

  const jwt = await getJWT()
  const host = config.isDev ? 'api.sandbox.push.apple.com' : 'api.push.apple.com'
  const payload = JSON.stringify({ aps: { alert: { title, body }, sound: 'default' } })

  return new Promise((resolve, reject) => {
    const client = http2.connect(`https://${host}`)
    client.on('error', reject)

    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      'authorization': `bearer ${jwt}`,
      'apns-topic': config.apns.bundleId,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
      'content-length': Buffer.byteLength(payload),
    })

    req.write(payload)
    req.end()

    req.on('response', (headers) => {
      const status = headers[':status']
      client.close()
      if (status === 200) resolve()
      else reject(new Error(`APNs error: status ${status}`))
    })

    req.on('error', (err) => { client.close(); reject(err) })
  })
}

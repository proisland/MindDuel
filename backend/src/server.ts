import { buildApp } from './app'
import { config } from './config'
import { activeConnectionCount } from './routes/v1/ws'

const DRAIN_TIMEOUT_MS = 30_000 // 30 seconds
const DRAIN_POLL_MS    = 500

async function start() {
  let app: Awaited<ReturnType<typeof buildApp>>
  try {
    app = await buildApp()
  } catch (err) {
    console.error('Fatal: failed to start server', err)
    process.exit(1)
  }

  const shutdown = async (signal: string) => {
    app.log.info(`${signal} received — starting graceful shutdown`)

    // Stop accepting new connections
    app.server.close()

    // Wait for active WebSocket connections to drain (up to DRAIN_TIMEOUT_MS)
    const deadline = Date.now() + DRAIN_TIMEOUT_MS
    while (activeConnectionCount() > 0 && Date.now() < deadline) {
      await new Promise(r => setTimeout(r, DRAIN_POLL_MS))
    }

    if (activeConnectionCount() > 0) {
      app.log.warn(`Drain timeout — ${activeConnectionCount()} WebSocket(s) still open, closing anyway`)
    }

    await app.close()
    process.exit(0)
  }

  process.once('SIGTERM', () => shutdown('SIGTERM'))
  process.once('SIGINT',  () => shutdown('SIGINT'))

  try {
    await app.listen({ port: config.port, host: '0.0.0.0' })
  } catch (err) {
    app.log.error(err)
    process.exit(1)
  }
}

start().catch(err => {
  console.error('Fatal: unhandled startup error', err)
  process.exit(1)
})

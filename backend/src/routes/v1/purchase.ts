import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { verifyTransaction, subscriptionExpiresAt, BUNDLE_ID } from '../../lib/appStore'

const purchaseBody = z.object({
  jwsRepresentation: z.string().min(1),
})

export default async function purchaseRoutes(app: FastifyInstance) {
  // POST /v1/me/purchase
  app.post('/', { onRequest: [app.authenticate] }, async (request, reply) => {
    const body = purchaseBody.safeParse(request.body)
    if (!body.success) {
      return reply.status(400).send({ error: 'Invalid request body', details: body.error.flatten() })
    }

    let tx
    try {
      tx = await verifyTransaction(body.data.jwsRepresentation)
    } catch (err) {
      app.log.warn({ err }, 'App Store transaction verification failed')
      return reply.status(400).send({ error: 'Invalid or unverifiable transaction' })
    }

    // Reject transactions for the wrong app
    if (tx.bundleId !== BUNDLE_ID) {
      return reply.status(400).send({ error: 'Bundle ID mismatch' })
    }

    // Reject revoked transactions
    if (tx.revocationDate) {
      return reply.status(400).send({ error: 'Transaction revoked' })
    }

    const expiresAt = subscriptionExpiresAt(tx)
    const isLifetime = expiresAt === null

    await app.prisma.user.update({
      where: { id: request.userId },
      data: {
        isPremium:        true,
        premiumExpiresAt: isLifetime ? null : expiresAt,
        premiumProductId: tx.productId,
      },
    })

    app.log.info({ userId: request.userId, productId: tx.productId, expiresAt }, 'Purchase recorded')

    return reply.send({
      isPremium:        true,
      premiumProductId: tx.productId,
      premiumExpiresAt: expiresAt?.toISOString() ?? null,
    })
  })
}

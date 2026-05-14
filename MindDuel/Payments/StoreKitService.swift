import StoreKit

@MainActor
final class StoreKitService: ObservableObject {

    static let shared = StoreKitService()

    // MARK: – Product IDs
    // Replace with real IDs from App Store Connect once the account is approved.
    static let monthlyId  = "no.mindduel.premium.monthly"
    static let yearlyId   = "no.mindduel.premium.yearly"
    static let lifetimeId = "no.mindduel.premium.lifetime"
    static let allIds     = [monthlyId, yearlyId, lifetimeId]

    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String? = nil

    private var updateListener: Task<Void, Never>?

    init() {
        updateListener = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit { updateListener?.cancel() }

    // MARK: – Load products

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.allIds)
            products = fetched.sorted {
                (Self.allIds.firstIndex(of: $0.id) ?? 0) < (Self.allIds.firstIndex(of: $1.id) ?? 0)
            }
        } catch {
            print("StoreKit: failed to load products: \(error)")
        }
    }

    // MARK: – Purchase

    func purchase(_ product: Product, userId: String) async throws {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        // appAccountToken ties the purchase to the MindDuel account, preventing
        // receipt sharing between different users.
        let token = appAccountToken(for: userId)
        let result = try await product.purchase(options: token.map { [.appAccountToken($0)] } ?? [])

        switch result {
        case .success(let verification):
            let jws = verification.jwsRepresentation
            let transaction = try checkVerified(verification)
            await sendToBackend(jws: jws)
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: – Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            print("StoreKit: restore failed: \(error)")
        }
    }

    // MARK: – Internals

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                let jws = result.jwsRepresentation
                guard case .verified(let transaction) = result else { continue }
                await self?.sendToBackend(jws: jws)
                await transaction.finish()
            }
        }
    }

    private func sendToBackend(jws: String) async {
        struct PurchaseBody: Encodable { let jwsRepresentation: String }
        struct PurchaseResponse: Decodable {
            let isPremium: Bool
            let premiumProductId: String?
            let premiumExpiresAt: String?
        }
        do {
            let _: PurchaseResponse = try await APIClient.shared.post(
                "me/purchase",
                body: PurchaseBody(jwsRepresentation: jws)
            )
        } catch {
            print("StoreKit: backend purchase recording failed: \(error)")
        }
    }

    private func appAccountToken(for userId: String) -> UUID? {
        // Derive a stable UUID from the user's CUID so the App Store can
        // correlate the transaction back to the MindDuel account.
        guard !userId.isEmpty else { return nil }
        var data = Data(userId.utf8)
        while data.count < 16 { data.append(contentsOf: data) }
        let bytes = Array(data.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2],  bytes[3],
            bytes[4], bytes[5], bytes[6],  bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

import Foundation
import Observation
import StoreKit

/// One non-consumable, bought once, restored automatically. No receipts to
/// validate on a server because there is no server.
@MainActor
@Observable
final class Entitlements {
    static let proID = "com.zawmbi.shut.pro"

    /// Mirrored into defaults for the non-view code that needs it — the
    /// engine's grace period — and so a relaunch starts with the last answer.
    private(set) var isPro: Bool = UserDefaults.standard.bool(forKey: PrefKey.proCached) {
        didSet { UserDefaults.standard.set(isPro, forKey: PrefKey.proCached) }
    }
    private(set) var product: Product?
    private(set) var purchasing: Bool = false
    private(set) var loadFailed: Bool = false

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let txn) = update else { continue }
                await txn.finish()
                await self?.refresh()
            }
        }
    }

    isolated deinit { updates?.cancel() }

    var priceText: String { product?.displayPrice ?? "$4.99" }

    func load() async {
        await refresh()
        do {
            product = try await Product.products(for: [Self.proID]).first
            loadFailed = product == nil
        } catch {
            loadFailed = true
        }
    }

    func refresh() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let txn) = entitlement, txn.productID == Self.proID {
                isPro = true
                return
            }
        }
        isPro = false
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product, !purchasing else { return false }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(.verified(let txn)) = result {
                await txn.finish()
                await refresh()
                return true
            }
        } catch {
            return false
        }
        return false
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
